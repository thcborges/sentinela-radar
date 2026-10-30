import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseManager SQLite R*Tree', () {
    late Database db;
    late DatabaseManager dbManager;

    setUp(() {
      db = sqlite3.openInMemory();
      dbManager = DatabaseManager(db);
      dbManager.initializeSchema();
    });

    tearDown(() {
      db.close();
    });

    test('initializeSchema deve criar tabelas pois, pois_index e db_metadata', () {
      // Verifica presença da tabela pois
      final tables = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('pois', 'pois_index', 'db_metadata')",
      );
      final names = tables.map((row) => row['name'] as String).toSet();

      expect(names, contains('pois'));
      expect(names, contains('pois_index'));
      expect(names, contains('db_metadata'));
    });

    test('deve inserir POI e sincronizar entrada no índice R*Tree', () {
      const poi = PoiPoint(
        id: 1,
        type: PoiType.fixedRadar,
        latitude: -23.550520,
        longitude: -46.633308,
        speedLimit: 60,
        direction: 90,
        roadName: 'Av. Paulista',
      );

      dbManager.insertPoi(poi);

      final row = db.select('SELECT * FROM pois WHERE id = 1').first;
      expect(row['id'], equals(1));
      expect(row['type'], equals(PoiType.fixedRadar.code));
      expect(row['speed_limit'], equals(60));
      expect(row['road_name'], equals('Av. Paulista'));

      // Verifica índice R*Tree
      final indexRow = db.select('SELECT * FROM pois_index WHERE id = 1').first;
      expect(indexRow['id'], equals(1));
      expect(indexRow['min_lat'], closeTo(-23.550520, 0.00001));
      expect(indexRow['min_lon'], closeTo(-46.633308, 0.00001));
    });

    test('busca espacial via R*Tree deve retornar apenas pontos dentro da bounding box', () {
      // 1. Ponto na Praça da Sé, SP (-23.550520, -46.633308)
      const sePoi = PoiPoint(
        id: 1,
        type: PoiType.fixedRadar,
        latitude: -23.550520,
        longitude: -46.633308,
        speedLimit: 50,
      );

      // 2. Ponto em Campinas (~85 km de distância)
      const campinasPoi = PoiPoint(
        id: 2,
        type: PoiType.fixedRadar,
        latitude: -22.90556,
        longitude: -47.06083,
        speedLimit: 80,
      );

      dbManager.insertPoi(sePoi);
      dbManager.insertPoi(campinasPoi);

      // Bounding box ao redor da Sé (raio de 1km ~ delta de 0.01 graus)
      final results = dbManager.searchBoundingBox(
        minLat: -23.56,
        maxLat: -23.54,
        minLon: -46.64,
        maxLon: -46.62,
      );

      expect(results.length, equals(1));
      expect(results.first.id, equals(1));
    });

    test('deve salvar e recuperar metadados de versão da base', () {
      dbManager.setMetadata('schema_version', '1');
      dbManager.setMetadata('total_pois', '72500');

      expect(dbManager.getMetadata('schema_version'), equals('1'));
      expect(dbManager.getMetadata('total_pois'), equals('72500'));
      expect(dbManager.getMetadata('nao_existente'), isNull);
    });

    test('deve inserir lista em lote com insertPoisBatch e retornar contagem total', () {
      final list = List.generate(
        100,
        (i) => PoiPoint(
          id: i + 10,
          type: PoiType.fixedRadar,
          latitude: -23.55 + (i * 0.0001),
          longitude: -46.63 + (i * 0.0001),
          speedLimit: 60,
        ),
      );

      dbManager.insertPoisBatch(list);

      expect(dbManager.getTotalCount(), equals(100));

      // Teste com lista vazia (no-op)
      dbManager.insertPoisBatch([]);
      expect(dbManager.getTotalCount(), equals(100));
    });
  });
}
