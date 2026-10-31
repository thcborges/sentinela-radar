import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/models/user_reported_poi.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/data/repository/custom_poi_repository.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  group('PoiRepository', () {
    late Database db;
    late DatabaseManager dbManager;
    late CustomPoiRepository customPoiRepository;
    late PoiRepository repository;

    setUp(() {
      db = sqlite3.openInMemory();
      dbManager = DatabaseManager(db);
      dbManager.initializeSchema();
      customPoiRepository = CustomPoiRepository(db);
      customPoiRepository.initializeSchema();
      repository = PoiRepository(dbManager, customPoiRepository: customPoiRepository);
    });

    tearDown(() {
      db.close();
    });

    test('findNearbyPois deve filtrar por raio geodésico exato e ordenar por proximidade', () async {
      const centerLat = -23.550520;
      const centerLon = -46.633308;

      // Ponto 1: ~300m ao Norte
      const p1 = PoiPoint(
        id: 1,
        type: PoiType.fixedRadar,
        latitude: -23.5478,
        longitude: -46.633308,
        speedLimit: 60,
      );

      // Ponto 2: ~150m ao Sul (mais próximo)
      const p2 = PoiPoint(
        id: 2,
        type: PoiType.physicalSpeedBump,
        latitude: -23.5518,
        longitude: -46.633308,
      );

      // Ponto 3: ~1500m (fora do raio de 1000m)
      const p3 = PoiPoint(
        id: 3,
        type: PoiType.trafficLightRadar,
        latitude: -23.5640,
        longitude: -46.633308,
      );

      await repository.savePoisBatch([p1, p2, p3]);

      final nearby = await repository.findNearbyPois(
        latitude: centerLat,
        longitude: centerLon,
        radiusMeters: 1000.0,
      );

      // Deve conter p2 e p1, descartando p3 (> 1000m)
      expect(nearby.length, equals(2));
      // Ordenado por menor distância: p2 (~150m) primeiro, depois p1 (~300m)
      expect(nearby.first.id, equals(2));
      expect(nearby.last.id, equals(1));
    });

    test('getCountByType deve retornar estatísticas agregadas por categoria', () async {
      await repository.savePoisBatch([
        const PoiPoint(id: 1, type: PoiType.fixedRadar, latitude: 0, longitude: 0),
        const PoiPoint(id: 2, type: PoiType.fixedRadar, latitude: 0.1, longitude: 0.1),
        const PoiPoint(id: 3, type: PoiType.trafficLightRadar, latitude: 0.2, longitude: 0.2),
        const PoiPoint(id: 4, type: PoiType.tollBooth, latitude: 0.3, longitude: 0.3),
        const PoiPoint(id: 5, type: PoiType.physicalSpeedBump, latitude: 0.4, longitude: 0.4),
        const PoiPoint(id: 6, type: PoiType.highwayPatrol, latitude: 0.5, longitude: 0.5),
      ]);

      final stats = await repository.getCountByType();

      expect(stats['radares'], equals(2));
      expect(stats['semaforos'], equals(1));
      expect(stats['pedagios'], equals(1));
      expect(stats['lombadas'], equals(1));
      expect(stats['policia'], equals(1));

      final total = await repository.getTotalCount();
      expect(total, equals(6));
    });

    test('metadados devem ser gravados e lidos corretamente pelo repositório', () async {
      await repository.setMetadata('last_sync', '2026-10-30T10:00:00');
      final val = await repository.getMetadata('last_sync');
      expect(val, equals('2026-10-30T10:00:00'));
    });

    test('savePoi deve salvar um único POI no repositório', () async {
      const singlePoi = PoiPoint(
        id: 99,
        type: PoiType.highwayPatrol,
        latitude: -22.0,
        longitude: -44.0,
        roadName: 'BR-116',
      );

      await repository.savePoi(singlePoi);
      final count = await repository.getTotalCount();
      expect(count, equals(1));
    });

    test('findNearbyPois deve mesclar e ordenar POIs da base oficial com POIs customizados do usuário', () async {
      // Ponto oficial da base: ~220m
      const officialPoi = PoiPoint(
        id: 1,
        type: PoiType.fixedRadar,
        latitude: -23.5525,
        longitude: -46.6333,
        speedLimit: 60,
      );
      await repository.savePoi(officialPoi);

      // Ponto customizado do usuário: ~75m (mais próximo que o oficial)
      await customPoiRepository.addCustomPoi(UserReportedPoi(
        type: PoiType.mobileRadar,
        latitude: -23.5512,
        longitude: -46.6333,
        speedLimit: 50,
        createdAt: DateTime.now(),
      ));

      final results = await repository.findNearbyPois(
        latitude: -23.5505,
        longitude: -46.6333,
        radiusMeters: 500,
      );

      expect(results.length, 2);
      expect(results.first.type, PoiType.mobileRadar);
      expect(results.first.source, 'user_reported');
      expect(results.last.type, PoiType.fixedRadar);
    });
  });
}
