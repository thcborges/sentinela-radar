import '../../domain/math/bounding_box.dart';
import '../../domain/math/haversine.dart';
import '../../domain/models/poi_model.dart';
import '../database/database_manager.dart';
import 'custom_poi_repository.dart';

/// Repositório central de acesso aos Pontos de Interesse (Radares, Semáforos, Lombadas e Pedágios).
class PoiRepository {
  final DatabaseManager dbManager;
  final CustomPoiRepository? customPoiRepository;

  PoiRepository(this.dbManager, {this.customPoiRepository});

  /// Busca todos os POIs localizados dentro do raio esférico [radiusMeters]
  /// a partir das coordenadas [latitude, longitude].
  ///
  /// Utiliza primeiro o índice espacial **SQLite R*Tree** para poda em Bounding Box,
  /// refinando em seguida pela fórmula exata de **Haversine** e ordenando os pontos
  /// por ordem crescente de distância. Incorpora também pontos cadastrados pelo usuário.
  Future<List<PoiPoint>> findNearbyPois({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final bbox = calculateBoundingBox(latitude, longitude, radiusMeters);

    final candidates = dbManager.searchBoundingBox(
      minLat: bbox.minLat,
      maxLat: bbox.maxLat,
      minLon: bbox.minLon,
      maxLon: bbox.maxLon,
    );

    // Refinamento geodésico exato e mapeamento de distância
    final List<({PoiPoint poi, double distance})> refined = [];

    for (final poi in candidates) {
      final dist = haversineDistance(
        latitude,
        longitude,
        poi.latitude,
        poi.longitude,
      );
      if (dist <= radiusMeters) {
        refined.add((poi: poi, distance: dist));
      }
    }

    // Incorporação de POIs customizados adicionados pelo usuário
    if (customPoiRepository != null) {
      final customPois = await customPoiRepository!.findNearbyCustomPois(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
      for (final poi in customPois) {
        final dist = haversineDistance(
          latitude,
          longitude,
          poi.latitude,
          poi.longitude,
        );
        refined.add((poi: poi, distance: dist));
      }
    }

    // Ordenação por menor distância até o veículo
    refined.sort((a, b) => a.distance.compareTo(b.distance));

    return refined.map((item) => item.poi).toList();
  }

  /// Salva um POI individualmente na base local.
  Future<void> savePoi(PoiPoint poi) async {
    dbManager.insertPoi(poi);
  }

  /// Salva uma lista de POIs em lote com transação atômica.
  Future<void> savePoisBatch(List<PoiPoint> pois) async {
    dbManager.insertPoisBatch(pois);
  }

  /// Retorna o número total de POIs ativos na base local.
  Future<int> getTotalCount() async {
    return dbManager.getTotalCount();
  }

  /// Retorna as estatísticas consolidadas da base divididas por categorias principais.
  Future<Map<String, int>> getCountByType() async {
    final result = dbManager.db.select('''
      SELECT type, COUNT(*) AS count
      FROM pois
      GROUP BY type;
    ''');

    final stats = <String, int>{
      'radares': 0,
      'semaforos': 0,
      'lombadas': 0,
      'pedagios': 0,
      'policia': 0,
    };

    for (final row in result) {
      final code = row['type'] as int;
      final count = row['count'] as int;
      final type = PoiType.fromCode(code);

      if (type == PoiType.fixedRadar || type == PoiType.mobileRadar) {
        stats['radares'] = (stats['radares'] ?? 0) + count;
      } else if (type.isRedLightEnforcement) {
        stats['semaforos'] = (stats['semaforos'] ?? 0) + count;
      } else if (type.isSpeedBump) {
        stats['lombadas'] = (stats['lombadas'] ?? 0) + count;
      } else if (type.isToll) {
        stats['pedagios'] = (stats['pedagios'] ?? 0) + count;
      } else if (type == PoiType.highwayPatrol) {
        stats['policia'] = (stats['policia'] ?? 0) + count;
      }
    }

    return stats;
  }

  /// Recupera o valor de um metadado textual da base.
  Future<String?> getMetadata(String key) async {
    return dbManager.getMetadata(key);
  }

  /// Define um metadado textual na base.
  Future<void> setMetadata(String key, String value) async {
    dbManager.setMetadata(key, value);
  }
}
