import 'package:sqlite3/sqlite3.dart';
import '../../core/geo/bounding_box.dart';
import '../../core/geo/haversine.dart';
import '../../core/models/poi_model.dart';
import '../../core/models/user_reported_poi.dart';

/// Repositório de persistência offline dos Pontos de Interesse reportados ou customizados pelo motorista.
/// Fica armazenado em tabela independente (`custom_pois`), protegido de limpezas durante sincronizações da base pública.
class CustomPoiRepository {
  final Database db;

  CustomPoiRepository(this.db);

  /// Cria a tabela de POIs customizados caso não exista.
  void initializeSchema() {
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

  /// Adiciona um novo POI customizado e retorna o objeto com o ID gerado pelo banco.
  Future<UserReportedPoi> addCustomPoi(UserReportedPoi poi) async {
    db.execute('''
      INSERT INTO custom_pois (
        type, latitude, longitude, speed_limit, direction, tolerance_angle, road_name, created_at, description
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''', [
      poi.type.code,
      poi.latitude,
      poi.longitude,
      poi.speedLimit,
      poi.direction,
      poi.toleranceAngle,
      poi.roadName,
      poi.createdAt.toIso8601String(),
      poi.description,
    ]);

    final generatedId = db.lastInsertRowId;
    return poi.copyWith(id: generatedId);
  }

  /// Recupera todos os POIs customizados registrados pelo usuário.
  Future<List<UserReportedPoi>> getAllCustomPois() async {
    final result = db.select('SELECT * FROM custom_pois ORDER BY created_at DESC;');
    return result.map((row) => UserReportedPoi.fromMap(row)).toList();
  }

  /// Recupera um POI customizado específico por seu ID.
  Future<UserReportedPoi?> getCustomPoiById(int id) async {
    final result = db.select('SELECT * FROM custom_pois WHERE id = ? LIMIT 1;', [id]);
    if (result.isEmpty) return null;
    return UserReportedPoi.fromMap(result.first);
  }

  /// Atualiza as informações de um POI customizado existente.
  Future<void> updateCustomPoi(UserReportedPoi poi) async {
    if (poi.id == null) return;
    db.execute('''
      UPDATE custom_pois SET
        type = ?,
        latitude = ?,
        longitude = ?,
        speed_limit = ?,
        direction = ?,
        tolerance_angle = ?,
        road_name = ?,
        description = ?
      WHERE id = ?;
    ''', [
      poi.type.code,
      poi.latitude,
      poi.longitude,
      poi.speedLimit,
      poi.direction,
      poi.toleranceAngle,
      poi.roadName,
      poi.description,
      poi.id,
    ]);
  }

  /// Exclui um POI customizado por seu ID.
  Future<void> deleteCustomPoi(int id) async {
    db.execute('DELETE FROM custom_pois WHERE id = ?;', [id]);
  }

  /// Limpa todos os POIs customizados cadastrados pelo usuário.
  Future<void> clearAllCustomPois() async {
    db.execute('DELETE FROM custom_pois;');
  }

  /// Retorna o total de POIs customizados registrados.
  Future<int> getCustomPoiCount() async {
    final result = db.select('SELECT COUNT(*) AS total FROM custom_pois;');
    return result.first['total'] as int;
  }

  /// Busca POIs customizados dentro do raio geodésico [radiusMeters],
  /// convertendo-os em [PoiPoint] para alimentar o motor de alertas.
  Future<List<PoiPoint>> findNearbyCustomPois({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final bbox = calculateBoundingBox(latitude, longitude, radiusMeters);

    final result = db.select('''
      SELECT * FROM custom_pois
      WHERE latitude >= ? AND latitude <= ?
        AND longitude >= ? AND longitude <= ?;
    ''', [bbox.minLat, bbox.maxLat, bbox.minLon, bbox.maxLon]);

    final List<({PoiPoint poi, double distance})> candidates = [];

    for (final row in result) {
      final userPoi = UserReportedPoi.fromMap(row);
      final dist = haversineDistance(
        latitude,
        longitude,
        userPoi.latitude,
        userPoi.longitude,
      );
      if (dist <= radiusMeters) {
        candidates.add((poi: userPoi.toPoiPoint(), distance: dist));
      }
    }

    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    return candidates.map((item) => item.poi).toList();
  }
}
