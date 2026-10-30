import 'dart:async';
import 'package:sqlite3/sqlite3.dart';
import '../../../core/models/poi_model.dart';
import '../models/passage_record.dart';

/// Repositório de persistência offline para histórico e telemetria de passagens.
/// Operação 100% isolada e privada na base local SQLite (sem qualquer envio para nuvem).
class PassageRepository {
  final Database _db;

  PassageRepository(this._db);

  /// Cria o schema da tabela de passagens se ainda não existir.
  void initSchema() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS passages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        poi_id INTEGER NOT NULL,
        poi_type INTEGER NOT NULL,
        vehicle_speed REAL NOT NULL,
        speed_limit INTEGER,
        timestamp TEXT NOT NULL,
        is_over_speed INTEGER NOT NULL,
        road_name TEXT,
        toll_fee REAL
      );
    ''');
    try {
      _db.execute('ALTER TABLE passages ADD COLUMN toll_fee REAL;');
    } catch (_) {
      // Coluna já existe
    }
    _db.execute('''
      CREATE INDEX IF NOT EXISTS idx_passages_timestamp ON passages(timestamp DESC);
    ''');
  }

  /// Insere um novo registro de passagem e retorna o ID gerado.
  Future<int> insertPassage(PassageRecord record) async {
    final stmt = _db.prepare('''
      INSERT INTO passages (
        poi_id, poi_type, vehicle_speed, speed_limit, timestamp, is_over_speed, road_name, toll_fee
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    ''');

    stmt.execute([
      record.poiId,
      record.poiType.code,
      record.vehicleSpeedKmh,
      record.speedLimit,
      record.timestamp.toIso8601String(),
      record.isOverSpeed ? 1 : 0,
      record.roadName,
      record.tollFee,
    ]);

    stmt.close();
    return _db.lastInsertRowId;
  }

  /// Recupera as passagens mais recentes limitadas por [limit].
  Future<List<PassageRecord>> getRecentPassages({int limit = 20}) async {
    final stmt = _db.prepare('''
      SELECT id, poi_id, poi_type, vehicle_speed, speed_limit, timestamp, is_over_speed, road_name, toll_fee
      FROM passages
      ORDER BY id DESC
      LIMIT ?;
    ''');

    final resultSet = stmt.select([limit]);
    final list = resultSet.map((row) {
      return PassageRecord(
        id: row['id'] as int?,
        poiId: row['poi_id'] as int,
        poiType: PoiType.fromCode(row['poi_type'] as int),
        vehicleSpeedKmh: (row['vehicle_speed'] as num).toDouble(),
        speedLimit: row['speed_limit'] as int?,
        timestamp: DateTime.parse(row['timestamp'] as String),
        isOverSpeed: (row['is_over_speed'] as int) == 1,
        roadName: (row['road_name'] as String?) ?? '',
        tollFee: (row['toll_fee'] as num?)?.toDouble(),
      );
    }).toList();

    stmt.close();
    return list;
  }

  /// Calcula estatísticas consolidadas de conformidade e gastos com pedágio.
  Future<StatsSummary> getStatsSummary() async {
    final resultSet = _db.select('''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN is_over_speed = 1 THEN 1 ELSE 0 END) as over_speed,
        SUM(CASE WHEN toll_fee IS NOT NULL THEN toll_fee ELSE 0.0 END) as total_toll
      FROM passages;
    ''');

    if (resultSet.isEmpty) {
      return const StatsSummary(totalPassages: 0, overSpeedPassages: 0, totalTollCost: 0.0);
    }

    final row = resultSet.first;
    final total = (row['total'] as int?) ?? 0;
    final overSpeed = (row['over_speed'] as int?) ?? 0;
    final totalToll = (row['total_toll'] as num?)?.toDouble() ?? 0.0;

    return StatsSummary(
      totalPassages: total,
      overSpeedPassages: overSpeed,
      totalTollCost: totalToll,
    );
  }

  /// Exclui permanentemente todos os registros do histórico.
  Future<void> clearHistory() async {
    _db.execute('DELETE FROM passages;');
  }
}
