import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/domain/export/dataset_exporter.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  const samplePois = [
    PoiPoint(
      id: 101,
      latitude: -23.5505,
      longitude: -46.6333,
      type: PoiType.fixedRadar,
      speedLimit: 60,
      direction: 90,
      toleranceAngle: 35.0,
      roadName: 'Av. 23 de Maio',
      city: 'São Paulo',
      state: 'SP',
      source: 'DNIT',
    ),
    PoiPoint(
      id: 102,
      latitude: -22.9068,
      longitude: -43.1728,
      type: PoiType.tollBooth,
      speedLimit: 40,
      roadName: 'Ponte Rio-Niterói, km 5',
      tollFeeCar: 6.20,
      operator: 'Ecoponte',
      city: 'Rio de Janeiro',
      state: 'RJ',
      source: 'ANTT',
    ),
  ];

  group('DatasetExporter', () {
    const exporter = DatasetExporter();

    group('exportToCsv', () {
      test('deve gerar cabeçalho e linhas CSV corretas com escape de aspas e vírgulas', () {
        final csv = exporter.exportToCsv(samplePois);
        final lines = const LineSplitter().convert(csv);

        expect(lines.first, 'id,latitude,longitude,type,speed_limit,direction,tolerance_angle,road_name,toll_fee_car,operator,city,state,source');
        expect(lines.length, 3);

        // Linha 1 (sem vírgula no nome: toll_fee_car e operator vazios -> 3 vírgulas)
        expect(lines[1], contains('101,-23.5505,-46.6333,fixedRadar,60,90,35.0,Av. 23 de Maio,,,São Paulo,SP,DNIT'));

        // Linha 2 (com vírgula no nome: deve estar entre aspas)
        expect(lines[2], contains('"Ponte Rio-Niterói, km 5"'));
        expect(lines[2], contains('tollBooth'));
        expect(lines[2], contains('6.2'));
        expect(lines[2], contains('Ecoponte'));
      });

      test('deve gerar apenas cabeçalho quando a lista for vazia', () {
        final csv = exporter.exportToCsv([]);
        final lines = const LineSplitter().convert(csv);
        expect(lines.length, 1);
        expect(lines.first, startsWith('id,latitude,longitude'));
      });
    });

    group('exportToJson', () {
      test('deve gerar JSON decodificável compatível com PoiSyncParser', () {
        final jsonStr = exporter.exportToJson(samplePois);
        final dynamic decoded = jsonDecode(jsonStr);

        expect(decoded, isA<Map<String, dynamic>>());
        final elements = (decoded as Map<String, dynamic>)['elements'] as List;
        expect(elements.length, 2);
        expect(elements.first['id'], 101);
        expect(elements.first['tags']['type'], 'fixedRadar');
        expect(elements.last['tags']['name'], 'Ponte Rio-Niterói, km 5');
        expect(elements.last['tags']['toll_fee_car'], '6.2');
      });
    });

    group('exportToSqliteDb & createCleanDatabase', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('sentinela_dataset_test_');
      });

      tearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('exportToSqliteDb deve compilar arquivo SQLite com R*Tree e metadados', () {
        final targetPath = '${tempDir.path}/test_bundle.db';
        final count = exporter.exportToSqliteDb(
          targetPath: targetPath,
          pois: samplePois,
          lastUpdated: DateTime.utc(2026, 11, 8, 3, 0),
        );

        expect(count, 2);
        expect(File(targetPath).existsSync(), isTrue);

        final rawDb = sqlite3.open(targetPath);
        final dbManager = DatabaseManager(rawDb);
        expect(dbManager.getTotalCount(), 2);
        expect(dbManager.getMetadata('total_count'), '2');
        expect(dbManager.getMetadata('last_updated'), '2026-11-08T03:00:00.000Z');

        final search = dbManager.searchBoundingBox(
          minLat: -24.0,
          maxLat: -23.0,
          minLon: -47.0,
          maxLon: -46.0,
        );
        expect(search.length, 1);
        expect(search.first.id, 101);

        rawDb.close();
      });

      test('createCleanDatabase deve gerar banco inicial limpo com schema criado e 0 POIs', () {
        final targetPath = '${tempDir.path}/clean_install.db';
        exporter.createCleanDatabase(targetPath: targetPath);

        expect(File(targetPath).existsSync(), isTrue);

        final rawDb = sqlite3.open(targetPath);
        final dbManager = DatabaseManager(rawDb);
        expect(dbManager.getTotalCount(), 0);
        expect(dbManager.getMetadata('total_count'), '0');

        final search = dbManager.searchBoundingBox(
          minLat: -90,
          maxLat: 90,
          minLon: -180,
          maxLon: 180,
        );
        expect(search, isEmpty);

        rawDb.close();
      });
    });
  });
}
