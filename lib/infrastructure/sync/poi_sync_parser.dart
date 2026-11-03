import 'dart:convert';
import '../../domain/math/bearing.dart';
import '../../domain/math/haversine.dart';
import '../../domain/models/poi_model.dart';

/// Utilitário de alto desempenho para parsing e deduplicação espacial de dados abertos
/// (OpenStreetMap / Overpass API, DNIT, INMETRO).
abstract class PoiSyncParser {
  /// Converte a carga JSON do Overpass API em lista de [PoiPoint].
  static List<PoiPoint> parseJsonPayload(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final List elements = data['elements'] ?? [];
    final List<PoiPoint> results = [];

    for (final el in elements) {
      if (el is! Map) continue;
      final lat = (el['lat'] as num?)?.toDouble();
      final lon = (el['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final id = (el['id'] as num?)?.toInt() ?? results.length + 1;
      final Map<String, dynamic> tags =
          (el['tags'] as Map<String, dynamic>?) ?? {};

      final road = (tags['ref'] ?? tags['name'] ?? '').toString();
      final operator = (tags['operator'] ?? tags['brand'])?.toString();

      // Extração de velocidade
      int? speed;
      final speedStr = tags['maxspeed']?.toString();
      if (speedStr != null) {
        final digits = speedStr.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isNotEmpty) {
          speed = int.tryParse(digits);
        }
      }

      // Extração de rumo/azimute cadastrado
      int? direction;
      final dirStr = tags['direction']?.toString();
      if (dirStr != null) {
        final d = double.tryParse(dirStr);
        if (d != null) {
          direction = normalizeBearing(d).round();
        }
      }

      // Classificação do tipo de POI
      final PoiType type;
      if (tags['barrier'] == 'toll_booth' || tags['type'] == 'tollBooth') {
        type = PoiType.tollBooth;
      } else if (tags['highway'] == 'toll_gantry' || tags['type'] == 'freeFlowToll') {
        type = PoiType.freeFlowToll;
      } else if (tags['amenity'] == 'police' || tags['highway'] == 'highway_patrol' || tags['type'] == 'highwayPatrol') {
        type = PoiType.highwayPatrol;
      } else if (tags['traffic_calming'] == 'electronic_bump' || tags['speed_camera:type'] == 'speed_display' || tags['type'] == 'electronicSpeedBump') {
        type = PoiType.electronicSpeedBump;
      } else if (tags.containsKey('traffic_calming') || tags['type'] == 'physicalSpeedBump') {
        type = PoiType.physicalSpeedBump;
      } else if (tags['enforcement'] == 'red_light' ||
          tags['camera:traffic_signals'] == 'yes' ||
          tags['red_light_camera'] == 'yes' ||
          tags['speed_camera:type'] == 'traffic_lights' ||
          tags['type'] == 'trafficLightRadar' ||
          tags['type'] == 'redLightCamera') {
        type = (speed != null || tags['type'] == 'trafficLightRadar')
            ? PoiType.trafficLightRadar
            : PoiType.redLightCamera;
      } else {
        type = PoiType.fixedRadar;
      }

      final city = tags['city']?.toString() ?? tags['addr:city']?.toString();
      final state = tags['state']?.toString() ?? tags['addr:state']?.toString();

      results.add(PoiPoint(
        id: id,
        type: type,
        latitude: lat,
        longitude: lon,
        speedLimit: speed,
        direction: direction,
        roadName: road,
        operator: operator,
        city: city,
        state: state,
        source: tags['source']?.toString() ?? 'OSM_OVERPASS',
      ));
    }

    return results;
  }

  /// Remove duplicatas espaciais (clusterização de pontos em proximidade <= [clusterRadiusMeters]),
  /// preservando rigorosamente radares de sentidos opostos em pistas duplas.
  static List<PoiPoint> deduplicatePois(
    List<PoiPoint> pois, {
    double clusterRadiusMeters = 35.0,
  }) {
    final List<PoiPoint> retained = [];

    for (final candidate in pois) {
      bool isDuplicate = false;

      for (final existing in retained) {
        // Verifica distância geodésica
        final distance = haversineDistance(
          candidate.latitude,
          candidate.longitude,
          existing.latitude,
          existing.longitude,
        );

        if (distance <= clusterRadiusMeters) {
          // Se ambos possuem direção definida e fiscalizam sentidos diferentes (ex: pista dupla oposta)
          if (candidate.direction != null && existing.direction != null) {
            final diff = bearingDifference(
              candidate.direction!,
              existing.direction!,
            );
            if (diff > 60.0) {
              // Não é duplicata: pistas opostas ou transversais em cruzamento
              continue;
            }
          }

          // Se mesma direção ou sem direção: duplicata espacial
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        retained.add(candidate);
      }
    }

    return retained;
  }
}
