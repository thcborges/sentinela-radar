import 'dart:io';
import 'package:flutter/services.dart';

/// Utilitário responsável pelo provisionamento da base SQLite pré-embarcada
/// no primeiro uso do aplicativo, garantindo operação 100% offline imediata sem requisições de rede.
class SeedDatabaseLoader {
  final AssetBundle _bundle;

  SeedDatabaseLoader({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  /// Garante que o banco de dados pré-embarcado esteja copiado para [targetPath].
  /// Se o arquivo já existir no destino, nenhuma operação de cópia é realizada.
  Future<bool> ensureDatabaseInstalled({
    required String targetPath,
    String assetPath = 'assets/db/sentinela_brasil.db',
  }) async {
    try {
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        return true;
      }

      // Garante criação do diretório pai se necessário
      final parentDir = targetFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      final data = await _bundle.load(assetPath);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Gravação atômica via arquivo temporário para evitar corrupção em desligamento
      final tempFile = File('$targetPath.tmp');
      await tempFile.writeAsBytes(bytes, flush: true);
      await tempFile.rename(targetPath);

      return true;
    } catch (_) {
      return false;
    }
  }
}
