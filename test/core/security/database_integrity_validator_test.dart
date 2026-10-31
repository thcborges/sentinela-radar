import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/security/database_integrity_validator.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('DatabaseIntegrityValidator (BDD - Validação Criptográfica SHA-256 e PRAGMA integrity_check)', () {
    late Directory tempDir;
    late DatabaseIntegrityValidator validator;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sentinela_integrity_test_');
      validator = const DatabaseIntegrityValidator();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('deve calcular corretamente o hash SHA-256 a partir de bytes e de um arquivo', () async {
      // Given: conteúdo conhecido em bytes e arquivo
      final bytes = Uint8List.fromList('Sentinela POIs Base 2026'.codeUnits);
      final expectedSha = sha256.convert(bytes).toString();

      final file = File('${tempDir.path}/test_data.bin');
      await file.writeAsBytes(bytes);

      // When: calculando hash
      final hashFromBytes = validator.calculateSha256FromBytes(bytes);
      final hashFromFile = await validator.calculateSha256(file);

      // Then: ambos coincidem com o SHA-256 real
      expect(hashFromBytes, equals(expectedSha));
      expect(hashFromFile, equals(expectedSha));
    });

    test('deve validar com sucesso quando o checksum bate (ignorando maiúsculas e espaços)', () async {
      final file = File('${tempDir.path}/checksum_ok.bin');
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      await file.writeAsBytes(data);
      final realHash = sha256.convert(data).toString();

      final isValid = await validator.verifyChecksum(
        file: file,
        expectedSha256: '  ${realHash.toUpperCase()}  ',
      );

      expect(isValid, isTrue);
    });

    test('deve rejeitar e invalidar quando o checksum difere (arquivo corrompido ou adulterado)', () async {
      final file = File('${tempDir.path}/checksum_corrupt.bin');
      await file.writeAsBytes([1, 2, 3, 4]);

      final isValid = await validator.verifyChecksum(
        file: file,
        expectedSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // hash do vazio
      );

      expect(isValid, isFalse);
    });

    test('deve retornar falso se o arquivo não existir ao calcular ou verificar checksum', () async {
      final nonExistentFile = File('${tempDir.path}/nao_existe.db');
      final isValid = await validator.verifyChecksum(
        file: nonExistentFile,
        expectedSha256: 'abc123',
      );

      expect(isValid, isFalse);
      expect(await validator.calculateSha256(nonExistentFile), isEmpty);
    });

    test('deve validar integridade estrutural do SQLite usando PRAGMA integrity_check', () {
      final dbPath = '${tempDir.path}/valid.db';
      final db = sqlite3.open(dbPath);
      db.execute('CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);');
      db.execute("INSERT INTO test_table (name) VALUES ('Radar 1');");

      final isIntegrityOk = validator.verifySqliteIntegrity(db);
      expect(isIntegrityOk, isTrue);

      db.close();
    });

    test('deve executar validação completa consolidada (validateDatabase)', () async {
      final dbPath = '${tempDir.path}/complete_test.db';
      final db = sqlite3.open(dbPath);
      db.execute('CREATE TABLE pois (id INTEGER PRIMARY KEY, lat REAL, lon REAL);');
      db.execute('INSERT INTO pois VALUES (1, -23.55, -46.63);');
      db.close();

      final dbFile = File(dbPath);
      final actualHash = await validator.calculateSha256(dbFile);

      final result = await validator.validateDatabase(
        dbFile: dbFile,
        expectedSha256: actualHash,
      );

      expect(result.isValid, isTrue);
      expect(result.isChecksumValid, isTrue);
      expect(result.isSqliteIntegrityValid, isTrue);
      expect(result.sha256Hash, equals(actualHash));
      expect(result.errorMessage, isNull);
    });

    test('deve reportar erro na validação completa se checksum não coincidir', () async {
      final dbPath = '${tempDir.path}/mismatch.db';
      final db = sqlite3.open(dbPath);
      db.execute('CREATE TABLE test (id INT);');
      db.close();

      final dbFile = File(dbPath);
      final result = await validator.validateDatabase(
        dbFile: dbFile,
        expectedSha256: 'bad_hash_123',
      );

      expect(result.isValid, isFalse);
      expect(result.isChecksumValid, isFalse);
      expect(result.errorMessage, contains('Checksum SHA-256 não confere'));
    });

    test('deve reportar erro se arquivo nao existir na validacao completa', () async {
      final nonExistent = File('${tempDir.path}/inexistente.db');
      final result = await validator.validateDatabase(dbFile: nonExistent);

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('não encontrado'));
      expect(result.toString(), contains('IntegrityValidationResult'));
    });

    test('deve reportar erro ao tentar abrir arquivo corrompido ou invalido', () async {
      final badFile = File('${tempDir.path}/corrupt.db');
      await badFile.writeAsString('I AM NOT A SQLITE DATABASE');

      final result = await validator.validateDatabase(dbFile: badFile);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, isNotNull);
    });
  });
}
