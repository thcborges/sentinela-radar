import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/models/user_reported_poi.dart';
import 'package:sentinela/data/repository/custom_poi_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database db;
  late CustomPoiRepository repository;

  setUp(() {
    db = sqlite3.openInMemory();
    repository = CustomPoiRepository(db);
    repository.initializeSchema();
  });

  tearDown(() {
    db.close();
  });

  group('CustomPoiRepository (Marcação Offline de POIs pelo Condutor)', () {
    test('deve inicializar tabela custom_pois com sucesso', () {
      final tables = db.select("SELECT name FROM sqlite_master WHERE type='table' AND name='custom_pois';");
      expect(tables.length, 1);
    });

    test('deve adicionar POI customizado e recuperar por ID e lista completa', () async {
      final now = DateTime.now();
      final poi = UserReportedPoi(
        type: PoiType.mobileRadar,
        latitude: -23.5505,
        longitude: -46.6333,
        speedLimit: 60,
        direction: 90,
        roadName: 'Av. Paulista',
        createdAt: now,
        description: 'Viatura com radar portátil',
      );

      final saved = await repository.addCustomPoi(poi);

      expect(saved.id, isNotNull);
      expect(saved.id, greaterThan(0));

      final fetched = await repository.getCustomPoiById(saved.id!);
      expect(fetched, isNotNull);
      expect(fetched!.type, PoiType.mobileRadar);
      expect(fetched.latitude, -23.5505);
      expect(fetched.longitude, -46.6333);
      expect(fetched.speedLimit, 60);
      expect(fetched.direction, 90);
      expect(fetched.roadName, 'Av. Paulista');
      expect(fetched.description, 'Viatura com radar portátil');

      final all = await repository.getAllCustomPois();
      expect(all.length, 1);
      expect(all.first.id, saved.id);

      final count = await repository.getCustomPoiCount();
      expect(count, 1);
    });

    test('deve atualizar POI customizado existente', () async {
      final poi = UserReportedPoi(
        type: PoiType.fixedRadar,
        latitude: -23.5500,
        longitude: -46.6300,
        speedLimit: 50,
        createdAt: DateTime.now(),
      );

      final saved = await repository.addCustomPoi(poi);

      final updatedPoi = saved.copyWith(
        speedLimit: 70,
        roadName: 'Radial Leste',
        description: 'Atualizado para 70 km/h',
      );

      await repository.updateCustomPoi(updatedPoi);

      final reloaded = await repository.getCustomPoiById(saved.id!);
      expect(reloaded!.speedLimit, 70);
      expect(reloaded.roadName, 'Radial Leste');
      expect(reloaded.description, 'Atualizado para 70 km/h');
    });

    test('deve excluir POI customizado individual e limpar todos', () async {
      final poi1 = await repository.addCustomPoi(UserReportedPoi(
        type: PoiType.physicalSpeedBump,
        latitude: -23.5510,
        longitude: -46.6310,
        createdAt: DateTime.now(),
      ));

      final poi2 = await repository.addCustomPoi(UserReportedPoi(
        type: PoiType.highwayPatrol,
        latitude: -23.5520,
        longitude: -46.6320,
        createdAt: DateTime.now(),
      ));

      expect(await repository.getCustomPoiCount(), 2);

      await repository.deleteCustomPoi(poi1.id!);
      expect(await repository.getCustomPoiCount(), 1);
      expect(await repository.getCustomPoiById(poi1.id!), isNull);
      expect(await repository.getCustomPoiById(poi2.id!), isNotNull);

      await repository.clearAllCustomPois();
      expect(await repository.getCustomPoiCount(), 0);
      expect(await repository.getAllCustomPois(), isEmpty);
    });

    test('deve buscar POIs customizados próximos por geodésica Haversine', () async {
      // Ponto a ~150 metros de distância
      await repository.addCustomPoi(UserReportedPoi(
        type: PoiType.mobileRadar,
        latitude: -23.5515,
        longitude: -46.6333,
        speedLimit: 60,
        createdAt: DateTime.now(),
      ));

      // Ponto distante a ~10 km
      await repository.addCustomPoi(UserReportedPoi(
        type: PoiType.fixedRadar,
        latitude: -23.6500,
        longitude: -46.7000,
        speedLimit: 80,
        createdAt: DateTime.now(),
      ));

      final nearby = await repository.findNearbyCustomPois(
        latitude: -23.5505,
        longitude: -46.6333,
        radiusMeters: 500,
      );

      expect(nearby.length, 1);
      expect(nearby.first.type, PoiType.mobileRadar);
      expect(nearby.first.source, 'user_reported');
      expect(nearby.first.id, lessThan(0)); // IDs negativos para POIs do usuário
    });

    test('toPoiPoint deve converter corretamente com ID negativo', () {
      final userPoi = UserReportedPoi(
        id: 42,
        type: PoiType.highwayPatrol,
        latitude: -22.9000,
        longitude: -43.2000,
        direction: 180,
        roadName: 'Via Dutra',
        createdAt: DateTime.now(),
      );

      final point = userPoi.toPoiPoint();
      expect(point.id, -42);
      expect(point.type, PoiType.highwayPatrol);
      expect(point.latitude, -22.9000);
      expect(point.longitude, -43.2000);
      expect(point.direction, 180);
      expect(point.roadName, 'Via Dutra');
      expect(point.source, 'user_reported');
    });

    test('UserReportedPoi toMap, fromMap e props devem suportar serialização completa', () {
      final now = DateTime(2026, 10, 30, 15, 0, 0);
      final poi = UserReportedPoi(
        id: 77,
        type: PoiType.electronicSpeedBump,
        latitude: -23.5500,
        longitude: -46.6300,
        speedLimit: 40,
        direction: 270,
        toleranceAngle: 45.0,
        roadName: 'Av. Ibirapuera',
        createdAt: now,
        description: 'Lombada eletrônica com display',
      );

      final map = poi.toMap();
      expect(map['id'], 77);
      expect(map['type'], PoiType.electronicSpeedBump.code);
      expect(map['speed_limit'], 40);
      expect(map['direction'], 270);
      expect(map['tolerance_angle'], 45.0);
      expect(map['road_name'], 'Av. Ibirapuera');
      expect(map['description'], 'Lombada eletrônica com display');

      final fromMap = UserReportedPoi.fromMap(map);
      expect(fromMap, equals(poi));
      expect(fromMap.props.length, 10);
    });
  });
}
