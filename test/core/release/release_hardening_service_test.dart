import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/release/release_hardening_service.dart';

void main() {
  group('ReleaseHardeningService (BDD - Hardening & Conformidade de Lojas)', () {
    late ReleaseHardeningService service;

    setUp(() {
      service = ReleaseHardeningService();
    });

    test('deve inicializar com configurações padrão de produção v1.0.0', () {
      expect(service.appVersion, '1.0.0+1');
      expect(service.applicationId, 'br.com.sentinela.sentinela');
    });

    test('deve auditar conformidade de privacidade atestando isolamento 100% offline', () async {
      final report = await service.auditEnvironment(
        isReleaseModeOverride: true,
        databaseSizeBytesOverride: 16 * 1024 * 1024, // 16 MB
        hasDatabaseOverride: true,
      );

      expect(report.isProductionReady, isTrue);
      expect(report.complianceScore, greaterThanOrEqualTo(90.0));

      final privacyCheck = report.checks.firstWhere((c) => c.id == 'privacy_zero_telemetry');
      expect(privacyCheck.passed, isTrue);
      expect(privacyCheck.severity, AuditSeverity.critical);

      final offlineCheck = report.checks.firstWhere((c) => c.id == 'offline_spatial_r_tree');
      expect(offlineCheck.passed, isTrue);
    });

    test('deve reprovar auditoria quando base de dados pré-embarcada estiver ausente', () async {
      final report = await service.auditEnvironment(
        isReleaseModeOverride: true,
        hasDatabaseOverride: false,
      );

      expect(report.isProductionReady, isFalse);
      final dbCheck = report.checks.firstWhere((c) => c.id == 'database_seed_integrity');
      expect(dbCheck.passed, isFalse);
      expect(dbCheck.severity, AuditSeverity.critical);
    });

    test('deve alertar em modo debug/profile como aviso sem bloquear release', () async {
      final report = await service.auditEnvironment(
        isReleaseModeOverride: false,
        hasDatabaseOverride: true,
        databaseSizeBytesOverride: 15 * 1024 * 1024,
      );

      final buildCheck = report.checks.firstWhere((c) => c.id == 'build_mode_release');
      expect(buildCheck.passed, isFalse);
      expect(buildCheck.severity, AuditSeverity.warning);
    });

    test('deve gerar manifesto de conformidade com Apple Privacy Manifest e Google Play Data Safety', () {
      final appleManifest = service.generateApplePrivacyManifest();
      expect(appleManifest['NSPrivacyTracking'], isFalse);
      expect((appleManifest['NSPrivacyCollectedDataTypes'] as List), isEmpty);
      expect((appleManifest['NSPrivacyAccessedAPITypes'] as List).length, greaterThanOrEqualTo(3));

      final googlePlaySafety = service.generateGooglePlayDataSafety();
      expect(googlePlaySafety['dataCollected'], isFalse);
      expect(googlePlaySafety['dataShared'], isFalse);
      expect(googlePlaySafety['ephemeralProcessing'], isTrue);
      expect(googlePlaySafety['locationTransferredOffDevice'], isFalse);
    });

    test('ReleaseAuditCheck e ReleaseHardeningReport devem suportar serialização e props', () {
      const check = ReleaseAuditCheck(
        id: 'test_check',
        name: 'Teste de Auditoria',
        category: ReleaseAuditCategory.buildSecurity,
        passed: true,
        severity: AuditSeverity.info,
        description: 'Descrição de teste',
      );

      final map = check.toMap();
      expect(map['id'], 'test_check');
      expect(map['passed'], isTrue);

      final restored = ReleaseAuditCheck.fromMap(map);
      expect(restored, equals(check));
      expect(restored.props, equals(check.props));

      final report = ReleaseHardeningReport(
        appVersion: '1.0.0+1',
        applicationId: 'br.com.sentinela.sentinela',
        timestamp: DateTime(2026, 10, 31),
        checks: const [check],
        summary: 'Resumo de conformidade',
      );

      final reportMap = report.toMap();
      expect(reportMap['appVersion'], '1.0.0+1');
      expect(reportMap['isProductionReady'], isTrue);

      final restoredReport = ReleaseHardeningReport.fromMap(reportMap);
      expect(restoredReport.appVersion, '1.0.0+1');
      expect(restoredReport.checks.length, 1);
      expect(restoredReport.props, equals(report.props));

      // Fallback em fromMap
      final fallbackCheck = ReleaseAuditCheck.fromMap({
        'category': 'unknown_category',
        'severity': 'unknown_severity',
      });
      expect(fallbackCheck.category, ReleaseAuditCategory.buildSecurity);
      expect(fallbackCheck.severity, AuditSeverity.info);
    });

    test('auditEnvironment deve verificar arquivo físico quando hasDatabaseOverride for null', () async {
      final report = await service.auditEnvironment(
        isReleaseModeOverride: true,
        dbPath: 'inexistent_path_test.db',
      );
      final dbCheck = report.checks.firstWhere((c) => c.id == 'database_seed_integrity');
      expect(dbCheck.passed, isFalse);
    });
  });
}
