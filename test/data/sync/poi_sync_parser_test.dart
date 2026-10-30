import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/sync/poi_sync_parser.dart';
import 'package:test/test.dart';

void main() {
  group('PoiSyncParser Overpass / OSM Payload', () {
    test('deve parsear nós com radar de velocidade, semáforo, lombada e pedágio', () {
      const jsonPayload = '''
      {
        "elements": [
          {
            "type": "node",
            "id": 1001,
            "lat": -23.5505,
            "lon": -46.6333,
            "tags": {
              "highway": "speed_camera",
              "maxspeed": "60 km/h",
              "direction": "180",
              "name": "Av. 23 de Maio"
            }
          },
          {
            "type": "node",
            "id": 1002,
            "lat": -23.5510,
            "lon": -46.6340,
            "tags": {
              "enforcement": "red_light",
              "camera:traffic_signals": "yes",
              "maxspeed": "50",
              "ref": "SP-015"
            }
          },
          {
            "type": "node",
            "id": 1003,
            "lat": -23.5520,
            "lon": -46.6350,
            "tags": {
              "traffic_calming": "bump"
            }
          },
          {
            "type": "node",
            "id": 1004,
            "lat": -23.5530,
            "lon": -46.6360,
            "tags": {
              "barrier": "toll_booth",
              "operator": "AutoBAn"
            }
          },
          {
            "type": "node",
            "id": 1005,
            "lat": -23.5540,
            "lon": -46.6370,
            "tags": {
              "highway": "toll_gantry",
              "operator": "FreeFlow CCR"
            }
          }
        ]
      }
      ''';

      final pois = PoiSyncParser.parseJsonPayload(jsonPayload);

      expect(pois.length, equals(5));

      // Radar Fixo
      expect(pois[0].type, equals(PoiType.fixedRadar));
      expect(pois[0].speedLimit, equals(60));
      expect(pois[0].direction, equals(180));
      expect(pois[0].roadName, equals('Av. 23 de Maio'));

      // Semáforo com radar (tem velocidade + red_light)
      expect(pois[1].type, equals(PoiType.trafficLightRadar));
      expect(pois[1].speedLimit, equals(50));
      expect(pois[1].roadName, equals('SP-015'));

      // Lombada física
      expect(pois[2].type, equals(PoiType.physicalSpeedBump));

      // Pedágio convencional
      expect(pois[3].type, equals(PoiType.tollBooth));
      expect(pois[3].operator, equals('AutoBAn'));

      // Pedágio Free Flow
      expect(pois[4].type, equals(PoiType.freeFlowToll));
      expect(pois[4].operator, equals('FreeFlow CCR'));
    });

    test('semáforo de sinal sem maxspeed deve ser classificado como redLightCamera', () {
      const jsonPayload = '''
      {
        "elements": [
          {
            "type": "node",
            "id": 2001,
            "lat": -23.5505,
            "lon": -46.6333,
            "tags": {
              "enforcement": "red_light"
            }
          }
        ]
      }
      ''';

      final pois = PoiSyncParser.parseJsonPayload(jsonPayload);
      expect(pois.length, equals(1));
      expect(pois.first.type, equals(PoiType.redLightCamera));
      expect(pois.first.speedLimit, isNull);
    });

    test('deduplicatePois deve agrupar pontos duplicados próximos (<= 35m) no mesmo sentido', () {
      final inputPois = [
        const PoiPoint(
          id: 1,
          type: PoiType.fixedRadar,
          latitude: -23.55000,
          longitude: -46.63000,
          speedLimit: 60,
          direction: 90,
        ),
        // Ponto a ~15 metros no mesmo sentido (duplicata de mapeamento)
        const PoiPoint(
          id: 2,
          type: PoiType.fixedRadar,
          latitude: -23.55010,
          longitude: -46.63005,
          speedLimit: 60,
          direction: 90,
        ),
        // Ponto a ~500 metros (ponto distinto)
        const PoiPoint(
          id: 3,
          type: PoiType.fixedRadar,
          latitude: -23.55400,
          longitude: -46.63000,
          speedLimit: 60,
          direction: 90,
        ),
      ];

      final deduplicated = PoiSyncParser.deduplicatePois(inputPois, clusterRadiusMeters: 35.0);

      expect(deduplicated.length, equals(2));
      expect(deduplicated.map((p) => p.id), containsAll([1, 3]));
    });

    test('deduplicatePois DEVE preservar radares em pista dupla com sentidos opostos', () {
      final dualCarriagewayPois = [
        // Sentido Norte (0°)
        const PoiPoint(
          id: 10,
          type: PoiType.fixedRadar,
          latitude: -23.55000,
          longitude: -46.63000,
          speedLimit: 80,
          direction: 0,
        ),
        // Sentido Sul (180°) a apenas 20 metros de distância (pista contrária)
        const PoiPoint(
          id: 20,
          type: PoiType.fixedRadar,
          latitude: -23.55015,
          longitude: -46.63005,
          speedLimit: 80,
          direction: 180,
        ),
      ];

      final result = PoiSyncParser.deduplicatePois(dualCarriagewayPois, clusterRadiusMeters: 35.0);

      // Ambos devem ser mantidos pois fiscalizam sentidos contrários!
      expect(result.length, equals(2));
      expect(result.map((p) => p.id), containsAll([10, 20]));
    });
  });
}
