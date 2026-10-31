import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/data/database/seed_database_loader.dart';

class MockAssetBundle extends Mock implements AssetBundle {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SeedDatabaseLoader Tests (BDD)', () {
    late Directory tempDir;
    late MockAssetBundle mockBundle;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sentinela_seed_test_');
      mockBundle = MockAssetBundle();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('deve copiar asset de seed para targetPath quando arquivo não existir', () async {
      final targetFile = File('${tempDir.path}/sentinela_brasil.db');
      expect(targetFile.existsSync(), isFalse);

      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final byteData = ByteData.view(dummyBytes.buffer);

      when(() => mockBundle.load('assets/db/sentinela_brasil.db'))
          .thenAnswer((_) async => byteData);

      final loader = SeedDatabaseLoader(bundle: mockBundle);
      final installed = await loader.ensureDatabaseInstalled(
        targetPath: targetFile.path,
      );

      expect(installed, isTrue);
      expect(targetFile.existsSync(), isTrue);
      expect(targetFile.readAsBytesSync(), equals(dummyBytes));
    });

    test('NÃO deve sobrescrever targetPath se o arquivo já existir', () async {
      final targetFile = File('${tempDir.path}/sentinela_brasil.db');
      final existingBytes = Uint8List.fromList([9, 9, 9]);
      targetFile.writeAsBytesSync(existingBytes);

      final loader = SeedDatabaseLoader(bundle: mockBundle);
      final installed = await loader.ensureDatabaseInstalled(
        targetPath: targetFile.path,
      );

      expect(installed, isTrue);
      // Não deve ter chamado o bundle
      verifyNever(() => mockBundle.load(any()));
      expect(targetFile.readAsBytesSync(), equals(existingBytes));
    });

    test('deve retornar false e tratar erro de IO graciosamente', () async {
      when(() => mockBundle.load(any())).thenThrow(Exception('Asset not found'));

      final loader = SeedDatabaseLoader(bundle: mockBundle);
      final installed = await loader.ensureDatabaseInstalled(
        targetPath: '${tempDir.path}/non_existent_folder/db.db',
      );

      expect(installed, isFalse);
    });

    test('construtor padrão sem bundle deve instanciar com rootBundle', () {
      final loader = SeedDatabaseLoader();
      expect(loader, isNotNull);
    });

    test('BUG #33 REGRESSÃO: arquivo .tmp deve ser excluído e não permanecer órfão no disco em caso de falha de I/O', () async {
      // Simula colisão onde targetPath é um diretório, fazendo o rename falhar com FileSystemException
      final conflictDir = Directory('${tempDir.path}/conflict_target.db');
      conflictDir.createSync();

      final tmpFile = File('${tempDir.path}/conflict_target.db.tmp');
      expect(tmpFile.existsSync(), isFalse);

      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final byteData = ByteData.view(dummyBytes.buffer);

      when(() => mockBundle.load(any())).thenAnswer((_) async => byteData);

      final loader = SeedDatabaseLoader(bundle: mockBundle);
      final installed = await loader.ensureDatabaseInstalled(
        targetPath: conflictDir.path,
      );

      expect(installed, isFalse);
      // O arquivo temporário .tmp NÃO pode permanecer órfão no disco
      expect(tmpFile.existsSync(), isFalse, reason: 'Arquivo .tmp residual deve ser removido no catch/finally');
    });
  });
}
