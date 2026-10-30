import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sentinela/core/backup/backup_restore_service.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/features/stats/models/passage_record.dart';
import 'package:sentinela/features/stats/repository/passage_repository.dart';

void main() {
  group('BackupRestoreService Tests (BDD - 100% Offline & Privacidade)', () {
    late Database rawDb;
    late PassageRepository passageRepo;
    late BackupRestoreService backupService;
    late Directory tempDir;

    setUp(() async {
      rawDb = sqlite3.openInMemory();
      passageRepo = PassageRepository(rawDb);
      passageRepo.initSchema();
      backupService = BackupRestoreService(passageRepository: passageRepo);
      tempDir = await Directory.systemTemp.createTemp('sentinela_backup_test_');
    });

    tearDown(() async {
      rawDb.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('deve exportar histórico de passagens e preferências para JSON válido', () async {
      final now = DateTime(2026, 10, 30, 15, 0);
      final record1 = PassageRecord(
        poiId: 10,
        timestamp: now,
        poiType: PoiType.fixedRadar,
        speedLimit: 60,
        vehicleSpeedKmh: 65.0,
        isOverSpeed: true,
        roadName: 'Av. 23 de Maio',
      );
      await passageRepo.insertPassage(record1);

      const prefs = AlertPreferences(
        speedToleranceKmh: 5.0,
        alertOnlyIfOverSpeed: true,
        anticipationTimeSeconds: 18.0,
      );

      final jsonString = await backupService.exportBackupToJson(preferences: prefs);

      expect(jsonString, contains('"version": 1'));
      expect(jsonString, contains('"speedToleranceKmh": 5.0'));
      expect(jsonString, contains('"road_name": "Av. 23 de Maio"'));
      expect(jsonString, contains('"is_over_speed": 1'));
    });

    test('deve restaurar passagens e preferências a partir de JSON válido', () async {
      const backupJson = '''
{
  "version": 1,
  "exportedAt": "2026-10-30T15:00:00.000",
  "preferences": {
    "speedToleranceKmh": 5.0,
    "speedTolerancePercent": 0.0,
    "alertOnlyIfOverSpeed": true,
    "anticipationTimeSeconds": 18.0,
    "soundEnabled": true,
    "voiceEnabled": true
  },
  "passages": [
    {
      "poi_id": 1,
      "poi_type": 1,
      "vehicle_speed": 78.0,
      "speed_limit": 80,
      "timestamp": "2026-10-30T14:30:00.000",
      "is_over_speed": 0,
      "road_name": "Marginal Pinheiros"
    },
    {
      "poi_id": 2,
      "poi_type": 3,
      "vehicle_speed": 55.0,
      "speed_limit": 50,
      "timestamp": "2026-10-30T14:45:00.000",
      "is_over_speed": 1,
      "road_name": "Av. Paulista"
    }
  ]
}
''';

      final summary = await backupService.importBackupFromJson(backupJson);

      expect(summary.isSuccess, isTrue);
      expect(summary.restoredPassagesCount, equals(2));
      expect(summary.preferencesRestored, isTrue);
      expect(summary.restoredPreferences?.speedToleranceKmh, equals(5.0));

      final passages = await passageRepo.getRecentPassages();
      expect(passages.length, equals(2));
      expect(passages.first.roadName, equals('Av. Paulista'));
      expect(passages.last.roadName, equals('Marginal Pinheiros'));
    });

    test('deve rejeitar JSON corrompido ou com formato inválido', () async {
      final summaryInvalidJson = await backupService.importBackupFromJson('json invalido {');
      expect(summaryInvalidJson.isSuccess, isFalse);
      expect(summaryInvalidJson.errorMessage, isNotNull);

      final summaryMissingFields = await backupService.importBackupFromJson('{"chave": "valor"}');
      expect(summaryMissingFields.isSuccess, isFalse);
      expect(summaryMissingFields.errorMessage, contains('Estrutura de backup incompatível'));
    });

    test('deve exportar e importar arquivo local com sucesso', () async {
      final filePath = '${tempDir.path}/sentinela_backup.json';
      final now = DateTime(2026, 10, 30, 12, 0);
      await passageRepo.insertPassage(PassageRecord(
        poiId: 20,
        timestamp: now,
        poiType: PoiType.tollBooth,
        speedLimit: null,
        vehicleSpeedKmh: 40.0,
        isOverSpeed: false,
        roadName: 'Ponte Rio-Niterói',
      ));

      final exportSuccess = await backupService.exportBackupToFile(filePath);
      expect(exportSuccess, isTrue);
      expect(File(filePath).existsSync(), isTrue);

      // Limpa banco
      await passageRepo.clearHistory();
      final emptyPassages = await passageRepo.getRecentPassages();
      expect(emptyPassages.isEmpty, isTrue);

      // Restaura do arquivo
      final summary = await backupService.importBackupFromFile(filePath);
      expect(summary.isSuccess, isTrue);
      expect(summary.restoredPassagesCount, equals(1));
      final restored = await passageRepo.getRecentPassages();
      expect(restored.first.roadName, equals('Ponte Rio-Niterói'));
    });

    test('importBackupFromFile deve retornar erro se arquivo não existir', () async {
      final summary = await backupService.importBackupFromFile('${tempDir.path}/inexistente.json');
      expect(summary.isSuccess, isFalse);
      expect(summary.errorMessage, contains('Arquivo não encontrado'));
    });

    test('importBackupFromFile deve capturar exceção de leitura e retornar erro', () async {
      final unreadable = File('${tempDir.path}/unreadable.json')..writeAsStringSync('{}');
      Process.runSync('chmod', ['000', unreadable.path]);
      try {
        final summary = await backupService.importBackupFromFile(unreadable.path);
        expect(summary.isSuccess, isFalse);
        expect(summary.errorMessage, contains('Erro na leitura do arquivo de backup'));
      } finally {
        Process.runSync('chmod', ['644', unreadable.path]);
      }
    });

    test('exportBackupToFile deve retornar false em caso de falha de I/O', () async {
      final failResult = await backupService.exportBackupToFile('/dev/null/impossible/path.json');
      expect(failResult, isFalse);
    });

    test('BackupSummary deve suportar igualdade por valor via Equatable', () {
      final now = DateTime(2026, 10, 30);
      final s1 = BackupSummary(
        isSuccess: true,
        restoredPassagesCount: 5,
        preferencesRestored: true,
        restoredPreferences: const AlertPreferences(speedToleranceKmh: 5),
        backupDate: now,
        errorMessage: null,
      );
      final s2 = BackupSummary(
        isSuccess: true,
        restoredPassagesCount: 5,
        preferencesRestored: true,
        restoredPreferences: const AlertPreferences(speedToleranceKmh: 5),
        backupDate: now,
        errorMessage: null,
      );

      expect(s1, equals(s2));
      expect(s1.props, equals(s2.props));
    });
  });
}
