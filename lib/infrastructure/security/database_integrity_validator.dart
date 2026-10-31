import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

/// Resultado consolidado da validação de integridade do banco de dados SQLite.
class IntegrityValidationResult {
  final bool isValid;
  final String sha256Hash;
  final bool isChecksumValid;
  final bool isSqliteIntegrityValid;
  final String? errorMessage;

  const IntegrityValidationResult({
    required this.isValid,
    required this.sha256Hash,
    required this.isChecksumValid,
    required this.isSqliteIntegrityValid,
    this.errorMessage,
  });

  @override
  String toString() =>
      'IntegrityValidationResult(isValid: $isValid, sha256: $sha256Hash, checksumValid: $isChecksumValid, pragmaOk: $isSqliteIntegrityValid, error: $errorMessage)';
}

/// Validador criptográfico de integridade da base de dados e payloads OTA.
///
/// Implementa checagem SHA-256 e verificação estrutural com SQLite `PRAGMA integrity_check`.
class DatabaseIntegrityValidator {
  const DatabaseIntegrityValidator();

  /// Calcula o hash SHA-256 a partir de um [Uint8List].
  String calculateSha256FromBytes(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Calcula o hash SHA-256 de um [File] no disco. Retorna string vazia se o arquivo não existir.
  Future<String> calculateSha256(File file) async {
    if (!await file.exists()) {
      return '';
    }
    final bytes = await file.readAsBytes();
    return calculateSha256FromBytes(bytes);
  }

  /// Verifica se o hash SHA-256 do arquivo coincide com o esperado (case-insensitive e ignorando espaços).
  Future<bool> verifyChecksum({
    required File file,
    required String expectedSha256,
  }) async {
    if (!await file.exists()) {
      return false;
    }
    final calculated = await calculateSha256(file);
    return calculated.toLowerCase() == expectedSha256.trim().toLowerCase();
  }

  /// Executa `PRAGMA integrity_check` na instância do SQLite e retorna `true` se o resultado for 'ok'.
  bool verifySqliteIntegrity(Database db) {
    try {
      final result = db.select('PRAGMA integrity_check;');
      if (result.isNotEmpty && result.first.columnAt(0).toString().toLowerCase() == 'ok') {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Executa validação completa em um arquivo SQLite (checksum opcional + PRAGMA integrity_check).
  Future<IntegrityValidationResult> validateDatabase({
    required File dbFile,
    String? expectedSha256,
  }) async {
    if (!await dbFile.exists()) {
      return const IntegrityValidationResult(
        isValid: false,
        sha256Hash: '',
        isChecksumValid: false,
        isSqliteIntegrityValid: false,
        errorMessage: 'Arquivo de banco de dados não encontrado no disco.',
      );
    }

    final calculatedHash = await calculateSha256(dbFile);

    bool checksumValid = true;
    if (expectedSha256 != null && expectedSha256.trim().isNotEmpty) {
      checksumValid = calculatedHash.toLowerCase() == expectedSha256.trim().toLowerCase();
      if (!checksumValid) {
        return IntegrityValidationResult(
          isValid: false,
          sha256Hash: calculatedHash,
          isChecksumValid: false,
          isSqliteIntegrityValid: false,
          errorMessage: 'Checksum SHA-256 não confere (esperado: $expectedSha256, obtido: $calculatedHash).',
        );
      }
    }

    bool sqliteIntegrityValid = false;
    try {
      final db = sqlite3.open(dbFile.path);
      try {
        sqliteIntegrityValid = verifySqliteIntegrity(db);
      } finally {
        db.close();
      }
    } catch (e) {
      return IntegrityValidationResult(
        isValid: false,
        sha256Hash: calculatedHash,
        isChecksumValid: checksumValid,
        isSqliteIntegrityValid: false,
        errorMessage: 'Falha ao abrir banco SQLite para verificação estrutural: $e',
      );
    }

    if (!sqliteIntegrityValid) {
      return IntegrityValidationResult(
        isValid: false,
        sha256Hash: calculatedHash,
        isChecksumValid: checksumValid,
        isSqliteIntegrityValid: false,
        errorMessage: 'SQLite PRAGMA integrity_check falhou. A base de dados pode estar corrompida.',
      );
    }

    return IntegrityValidationResult(
      isValid: true,
      sha256Hash: calculatedHash,
      isChecksumValid: checksumValid,
      isSqliteIntegrityValid: true,
      errorMessage: null,
    );
  }
}
