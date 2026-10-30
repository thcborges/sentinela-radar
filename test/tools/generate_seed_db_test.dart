import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../tools/generate_seed_db.dart';

void main() {
  group('Seed Database Generator (tools/generate_seed_db.dart)', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sentinela_seed_test_');
      dbPath = '${tempDir.path}/test_seed.db';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('deve criar banco de seed com R*Tree, tabela pois e metadados', () async {
      final samplePois = [
        const PoiPoint(
          id: 1,
          latitude: -23.5505,
          longitude: -46.6333,
          type: PoiType.fixedRadar,
          speedLimit: 60,
          roadName: 'Av. Paulista',
        ),
        const PoiPoint(
          id: 2,
          latitude: -23.5510,
          longitude: -46.6340,
          type: PoiType.trafficLightRadar,
          speedLimit: 50,
          roadName: 'Rua Augusta',
        ),
      ];

      final count = await generateSeedDatabase(
        outputPath: dbPath,
        pois: samplePois,
      );

      expect(count, equals(2));
      expect(File(dbPath).existsSync(), isTrue);

      final db = sqlite3.open(dbPath);

      // 1. Verifica pois
      final poisResult = db.select('SELECT COUNT(*) as count FROM pois;');
      expect(poisResult.first['count'], equals(2));

      // 2. Verifica pois_index (R*Tree)
      final indexResult = db.select('SELECT COUNT(*) as count FROM pois_index;');
      expect(indexResult.first['count'], equals(2));

      // 3. Verifica metadados
      final metaResult = db.select("SELECT value FROM db_metadata WHERE key = 'total_count';");
      expect(metaResult.first['value'], equals('2'));

      db.close();
    });

    test('deve gerar base default de radares quando lista não for informada', () async {
      final count = await generateSeedDatabase(
        outputPath: dbPath,
      );

      expect(count, isPositive);
      expect(File(dbPath).existsSync(), isTrue);

      final db = sqlite3.open(dbPath);
      final meta = db.select("SELECT value FROM db_metadata WHERE key = 'source';");
      expect(meta.first['value'], equals('OpenStreetMap / Dados Abertos Brasil'));
      db.close();
    });
  });
}
