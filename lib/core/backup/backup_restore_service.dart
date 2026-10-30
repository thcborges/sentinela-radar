import 'dart:convert';
import 'dart:io';
import 'package:equatable/equatable.dart';
import '../engine/alert_machine.dart';
import '../engine/alert_preferences.dart';
import '../../features/stats/models/passage_record.dart';
import '../../features/stats/repository/passage_repository.dart';

/// Sumário com o resultado da restauração de um backup local.
class BackupSummary extends Equatable {
  final bool isSuccess;
  final int restoredPassagesCount;
  final bool preferencesRestored;
  final AlertPreferences? restoredPreferences;
  final DateTime? backupDate;
  final String? errorMessage;

  const BackupSummary({
    required this.isSuccess,
    this.restoredPassagesCount = 0,
    this.preferencesRestored = false,
    this.restoredPreferences,
    this.backupDate,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [
        isSuccess,
        restoredPassagesCount,
        preferencesRestored,
        restoredPreferences,
        backupDate,
        errorMessage,
      ];
}

/// Serviço de exportação e restauração de dados 100% offline do Sentinela.
/// Permite ao motorista manter cópias de segurança do seu histórico e preferências
/// em formato JSON aberto, sem dependência de nuvem e com garantia absoluta de privacidade.
class BackupRestoreService {
  final PassageRepository _passageRepository;
  final AlertMachine? _alertMachine;

  BackupRestoreService({
    required PassageRepository passageRepository,
    AlertMachine? alertMachine,
  })  : _passageRepository = passageRepository,
        _alertMachine = alertMachine;

  /// Exporta todo o histórico de passagens e as preferências para uma string JSON.
  Future<String> exportBackupToJson({AlertPreferences? preferences}) async {
    final passages = await _passageRepository.getRecentPassages(limit: 50000);
    final prefs = preferences ?? _alertMachine?.preferences ?? const AlertPreferences();
    final payload = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'preferences': prefs.toJson(),
      'passages': passages.map((p) => p.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Restaura passagens e preferências a partir de uma string JSON.
  Future<BackupSummary> importBackupFromJson(String jsonString) async {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return const BackupSummary(
          isSuccess: false,
          errorMessage: 'Estrutura de backup incompatível.',
        );
      }

      if (!decoded.containsKey('version') || !decoded.containsKey('passages')) {
        return const BackupSummary(
          isSuccess: false,
          errorMessage: 'Estrutura de backup incompatível: campos ausentes.',
        );
      }

      final passagesList = decoded['passages'] as List<dynamic>? ?? [];
      AlertPreferences? prefs;
      if (decoded['preferences'] is Map<String, dynamic>) {
        prefs = AlertPreferences.fromJson(
            decoded['preferences'] as Map<String, dynamic>);
        _alertMachine?.updatePreferences(prefs);
      }

      DateTime? backupDate;
      if (decoded['exportedAt'] is String) {
        backupDate = DateTime.tryParse(decoded['exportedAt'] as String);
      }

      int restoredCount = 0;
      for (final item in passagesList) {
        if (item is Map<String, dynamic>) {
          final record = PassageRecord.fromMap(item);
          await _passageRepository.insertPassage(record);
          restoredCount++;
        }
      }

      return BackupSummary(
        isSuccess: true,
        restoredPassagesCount: restoredCount,
        preferencesRestored: prefs != null,
        restoredPreferences: prefs,
        backupDate: backupDate,
      );
    } catch (e) {
      return BackupSummary(
        isSuccess: false,
        errorMessage: 'Falha ao processar backup JSON: $e',
      );
    }
  }

  /// Grava o backup diretamente em arquivo no sistema de arquivos local.
  Future<bool> exportBackupToFile(
    String filePath, {
    AlertPreferences? preferences,
  }) async {
    try {
      final json = await exportBackupToJson(preferences: preferences);
      final file = File(filePath);
      await file.writeAsString(json, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restaura dados diretamente de um arquivo no sistema de arquivos local.
  Future<BackupSummary> importBackupFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const BackupSummary(
          isSuccess: false,
          errorMessage: 'Arquivo não encontrado no caminho informado.',
        );
      }
      final json = await file.readAsString();
      return await importBackupFromJson(json);
    } catch (e) {
      return BackupSummary(
        isSuccess: false,
        errorMessage: 'Erro na leitura do arquivo de backup: $e',
      );
    }
  }
}
