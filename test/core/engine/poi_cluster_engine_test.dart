import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/poi_cluster_engine.dart';
import 'package:sentinela/core/models/poi_model.dart';

void main() {
  group('PoiClusterEngine (Clusterização Espacial e Fusão Hierárquica de POIs Múltiplos)', () {
    late PoiClusterEngine engine;

    setUp(() {
      engine = const PoiClusterEngine(clusterRadiusMeters: 45.0);
    });

    test('deve retornar lista vazia quando não há POIs', () {
      final clusters = engine.clusterPois([]);
      expect(clusters, isEmpty);
    });

    test('deve manter POI único como um cluster individual sem pontos associados', () {
      final poi = const PoiPoint(
        id: 101,
        type: PoiType.fixedRadar,
        latitude: -23.5505,
        longitude: -46.6333,
        speedLimit: 60,
        roadName: 'Av. 23 de Maio',
      );

      final clusters = engine.clusterPois([poi]);

      expect(clusters.length, equals(1));
      final cluster = clusters.first;
      expect(cluster.primaryPoi, equals(poi));
      expect(cluster.isMultiPoint, isFalse);
      expect(cluster.associatedPois, isEmpty);
      expect(cluster.compositeTtsPhrase, contains('Radar fixo, 60 km/h'));
    });

    test('deve agrupar Radar Fixo e Câmera de Sinal colocalizados a 20 metros em cluster unificado', () {
      final radar = const PoiPoint(
        id: 201,
        type: PoiType.fixedRadar,
        latitude: -23.55050,
        longitude: -46.63330,
        speedLimit: 50,
        roadName: 'Av. Paulista',
      );

      final redLight = const PoiPoint(
        id: 202,
        type: PoiType.redLightCamera,
        latitude: -23.55060, // ~11 metros de distância
        longitude: -46.63330,
        roadName: 'Av. Paulista c/ Alameda Campinas',
      );

      final clusters = engine.clusterPois([radar, redLight]);

      expect(clusters.length, equals(1));
      final cluster = clusters.first;
      expect(cluster.isMultiPoint, isTrue);
      expect(cluster.primaryPoi.type, equals(PoiType.fixedRadar));
      expect(cluster.associatedPois.length, equals(1));
      expect(cluster.associatedPois.first.type, equals(PoiType.redLightCamera));

      // Frase composta inteligente evitando cacofonia
      expect(cluster.compositeTtsPhrase, contains('Radar fixo, 50 km/h'));
      expect(cluster.compositeTtsPhrase, contains('fiscalização de sinal vermelho'));
    });

    test('deve agrupar Radar Fixo e Lombada Física colocalizados', () {
      final radar = const PoiPoint(
        id: 301,
        type: PoiType.fixedRadar,
        latitude: -23.5505,
        longitude: -46.6333,
        speedLimit: 40,
      );

      final bump = const PoiPoint(
        id: 302,
        type: PoiType.physicalSpeedBump,
        latitude: -23.5506, // ~15m
        longitude: -46.6333,
      );

      final clusters = engine.clusterPois([radar, bump]);

      expect(clusters.length, equals(1));
      final cluster = clusters.first;
      expect(cluster.primaryPoi.type, equals(PoiType.fixedRadar));
      expect(cluster.compositeTtsPhrase, contains('Radar fixo, 40 km/h'));
      expect(cluster.compositeTtsPhrase, contains('lombada'));
    });

    test('não deve agrupar POIs distantes (>45m) mesmo na mesma via', () {
      final poi1 = const PoiPoint(
        id: 401,
        type: PoiType.fixedRadar,
        latitude: -23.5500,
        longitude: -46.6333,
        speedLimit: 60,
      );

      final poi2 = const PoiPoint(
        id: 402,
        type: PoiType.fixedRadar,
        latitude: -23.5520, // ~222 metros de distância
        longitude: -46.6333,
        speedLimit: 60,
      );

      final clusters = engine.clusterPois([poi1, poi2]);

      expect(clusters.length, equals(2));
      expect(clusters[0].isMultiPoint, isFalse);
      expect(clusters[1].isMultiPoint, isFalse);
    });

    test('não deve agrupar POIs em sentidos estritamente opostos em pista dupla (diferença azimutal >= 120°)', () {
      final northRadar = const PoiPoint(
        id: 501,
        type: PoiType.fixedRadar,
        latitude: -23.5505,
        longitude: -46.6333,
        speedLimit: 80,
        direction: 0, // Sentido Norte
      );

      final southRadar = const PoiPoint(
        id: 502,
        type: PoiType.fixedRadar,
        latitude: -23.5506, // 11m
        longitude: -46.6333,
        speedLimit: 80,
        direction: 180, // Sentido Sul (pista oposta)
      );

      final clusters = engine.clusterPois([northRadar, southRadar]);

      expect(clusters.length, equals(2)); // Devem permanecer independentes!
    });

    test('deve priorizar corretamente Semáforo com Radar e Pedágio Free Flow em severidade', () {
      final toll = const PoiPoint(
        id: 601,
        type: PoiType.freeFlowToll,
        latitude: -23.5505,
        longitude: -46.6333,
        roadName: 'BR-101',
      );

      final radar = const PoiPoint(
        id: 602,
        type: PoiType.trafficLightRadar,
        latitude: -23.5506,
        longitude: -46.6333,
        speedLimit: 70,
        roadName: 'BR-101',
      );

      final clusters = engine.clusterPois([toll, radar]);

      expect(clusters.length, equals(1));
      // trafficLightRadar tem severidade maior do que toll
      expect(clusters.first.primaryPoi.type, equals(PoiType.trafficLightRadar));
      expect(clusters.first.associatedPois.first.type, equals(PoiType.freeFlowToll));
      expect(clusters.first.compositeTtsPhrase, contains('Semáforo com radar'));
      expect(clusters.first.compositeTtsPhrase, contains('Pórtico Free Flow'));
    });

    test('deve formatar adequadamente secundários de pedágio convencional, posto policial e radar móvel', () {
      final tlRadar = const PoiPoint(
        id: 701,
        type: PoiType.trafficLightRadar,
        latitude: -23.5505,
        longitude: -46.6333,
        speedLimit: 60,
      );
      final tollBooth = const PoiPoint(
        id: 702,
        type: PoiType.tollBooth,
        latitude: -23.55051,
        longitude: -46.63331,
      );
      final patrol = const PoiPoint(
        id: 703,
        type: PoiType.highwayPatrol,
        latitude: -23.55052,
        longitude: -46.63332,
      );
      final mobile = const PoiPoint(
        id: 704,
        type: PoiType.mobileRadar,
        latitude: -23.55053,
        longitude: -46.63333,
        speedLimit: 60,
      );
      final fixed = const PoiPoint(
        id: 705,
        type: PoiType.fixedRadar,
        latitude: -23.55054,
        longitude: -46.63334,
        speedLimit: 60,
      );

      final clusters = engine.clusterPois([tlRadar, tollBooth, patrol, mobile, fixed]);
      expect(clusters.length, equals(1));
      final phrase = clusters.first.compositeTtsPhrase;
      expect(phrase, contains('praça de pedágio'));
      expect(phrase, contains('posto policial'));
      expect(phrase, contains('radar móvel'));
      expect(phrase, contains('radar fixo'));
    });

    test('PoiCluster deve suportar igualdade Equatable e expor allPois', () {
      const p1 = PoiPoint(id: 1, type: PoiType.fixedRadar, latitude: -23.0, longitude: -46.0);
      const p2 = PoiPoint(id: 2, type: PoiType.redLightCamera, latitude: -23.0001, longitude: -46.0);

      const c1 = PoiCluster(
        primaryPoi: p1,
        associatedPois: [p2],
        centerLatitude: -23.00005,
        centerLongitude: -46.0,
        compositeTtsPhrase: 'Teste',
      );

      const c2 = PoiCluster(
        primaryPoi: p1,
        associatedPois: [p2],
        centerLatitude: -23.00005,
        centerLongitude: -46.0,
        compositeTtsPhrase: 'Teste',
      );

      expect(c1, equals(c2));
      expect(c1.allPois, equals([p1, p2]));
      expect(c1.props, contains(p1));
    });
  });
}
