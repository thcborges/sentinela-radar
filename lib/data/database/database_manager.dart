import 'package:sqlite3/sqlite3.dart';
import '../../core/models/poi_model.dart';

/// Gerenciador de persistência local SQLite compilado com módulo espacial R*Tree.
class DatabaseManager {
  final Database db;

  DatabaseManager(this.db);

  /// Cria o esquema relacional e os índices espaciais virtuais R*Tree caso não existam.
  void initializeSchema() {
    db.execute('PRAGMA foreign_keys = ON;');

    // Tabela principal de POIs
    db.execute('''
      CREATE TABLE IF NOT EXISTS pois (
          id INTEGER PRIMARY KEY,
          type INTEGER NOT NULL,
          speed_limit INTEGER,
          direction INTEGER,
          tolerance_angle REAL DEFAULT 35.0,
          road_name TEXT,
          toll_fee_car REAL,
          operator TEXT,
          city TEXT,
          state TEXT,
          source TEXT
      );
    ''');

    // Índice espacial R*Tree nativo do SQLite para busca por Bounding Box em microssegundos
    db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS pois_index USING rtree(
          id,
          min_lat, max_lat,
          min_lon, max_lon
      );
    ''');

    // Metadados do banco (versão, estatísticas, última sincronização)
    db.execute('''
      CREATE TABLE IF NOT EXISTS db_metadata (
          key TEXT PRIMARY KEY,
          value TEXT
      );
    ''');

    // Tabela de POIs customizados cadastrados pelo condutor (100% offline e persistente)
    db.execute('''
      CREATE TABLE IF NOT EXISTS custom_pois (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        speed_limit INTEGER,
        direction INTEGER,
        tolerance_angle REAL DEFAULT 35.0,
        road_name TEXT,
        created_at TEXT NOT NULL,
        description TEXT
      );
    ''');
  }

  /// Insere ou substitui um POI e sincroniza seu registro correspondente no índice R*Tree.
  void insertPoi(PoiPoint poi) {
    db.execute('BEGIN TRANSACTION;');
    try {
      db.execute('''
        INSERT OR REPLACE INTO pois (
          id, type, speed_limit, direction, tolerance_angle, road_name, toll_fee_car, operator, city, state, source
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''', [
        poi.id,
        poi.type.code,
        poi.speedLimit,
        poi.direction,
        poi.toleranceAngle,
        poi.roadName,
        poi.tollFeeCar,
        poi.operator,
        poi.city,
        poi.state,
        poi.source,
      ]);

      // R*Tree armazena caixas; para um ponto infinitesimal, min == max
      db.execute('''
        INSERT OR REPLACE INTO pois_index (id, min_lat, max_lat, min_lon, max_lon)
        VALUES (?, ?, ?, ?, ?);
      ''', [
        poi.id,
        poi.latitude,
        poi.latitude,
        poi.longitude,
        poi.longitude,
      ]);

      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Insere uma lista de POIs em lote com transação única de alta performance.
  void insertPoisBatch(List<PoiPoint> pois) {
    if (pois.isEmpty) return;

    db.execute('BEGIN TRANSACTION;');
    try {
      final insertPoiStmt = db.prepare('''
        INSERT OR REPLACE INTO pois (
          id, type, speed_limit, direction, tolerance_angle, road_name, toll_fee_car, operator, city, state, source
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''');

      final insertIndexStmt = db.prepare('''
        INSERT OR REPLACE INTO pois_index (id, min_lat, max_lat, min_lon, max_lon)
        VALUES (?, ?, ?, ?, ?);
      ''');

      for (final poi in pois) {
        insertPoiStmt.execute([
          poi.id,
          poi.type.code,
          poi.speedLimit,
          poi.direction,
          poi.toleranceAngle,
          poi.roadName,
          poi.tollFeeCar,
          poi.operator,
          poi.city,
          poi.state,
          poi.source,
        ]);

        insertIndexStmt.execute([
          poi.id,
          poi.latitude,
          poi.latitude,
          poi.longitude,
          poi.longitude,
        ]);
      }

      insertPoiStmt.close();
      insertIndexStmt.close();

      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Consulta espacial otimizada pelo índice R*Tree retornando todos os POIs que intersectam
  /// a bounding box [minLat, maxLat, minLon, maxLon].
  List<PoiPoint> searchBoundingBox({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) {
    final query = '''
      SELECT p.id, p.type, p.speed_limit, p.direction, p.tolerance_angle,
             p.road_name, p.toll_fee_car, p.operator, p.city, p.state, p.source,
             idx.min_lat AS lat, idx.min_lon AS lon
      FROM pois p
      JOIN pois_index idx ON p.id = idx.id
      WHERE idx.min_lat <= ? AND idx.max_lat >= ?
        AND idx.min_lon <= ? AND idx.max_lon >= ?;
    ''';

    final resultSet = db.select(query, [maxLat, minLat, maxLon, minLon]);

    return resultSet.map((row) {
      final typeCode = row['type'] as int;
      return PoiPoint(
        id: row['id'] as int,
        type: PoiType.fromCode(typeCode),
        latitude: (row['lat'] as num).toDouble(),
        longitude: (row['lon'] as num).toDouble(),
        speedLimit: row['speed_limit'] as int?,
        direction: row['direction'] as int?,
        toleranceAngle: (row['tolerance_angle'] as num?)?.toDouble() ?? 35.0,
        roadName: (row['road_name'] as String?) ?? '',
        tollFeeCar: (row['toll_fee_car'] as num?)?.toDouble(),
        operator: row['operator'] as String?,
        city: row['city'] as String?,
        state: row['state'] as String?,
        source: row['source'] as String?,
      );
    }).toList();
  }

  /// Recupera o valor de um metadado textual pela chave.
  String? getMetadata(String key) {
    final result = db.select(
      'SELECT value FROM db_metadata WHERE key = ? LIMIT 1;',
      [key],
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  /// Define ou atualiza um metadado textual.
  void setMetadata(String key, String value) {
    db.execute(
      'INSERT OR REPLACE INTO db_metadata (key, value) VALUES (?, ?);',
      [key, value],
    );
  }

  /// Retorna a contagem total de registros ativos na base.
  int getTotalCount() {
    final result = db.select('SELECT COUNT(*) AS total FROM pois;');
    return result.first['total'] as int;
  }
}
