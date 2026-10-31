import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/diagnostics/system_diagnostics.dart';
import 'package:sentinela/core/location/location_service_interface.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/network/connectivity_checker.dart';
import 'package:sentinela/core/release/release_hardening_service.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sqlite3/sqlite3.dart';

class FakeLocationService implements LocationService {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.always;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.always;

  @override
  Stream<VehiclePosition> getPositionStream({
    int distanceFilterMeters = 2,
    int intervalMs = 1000,
  }) =>
      const Stream.empty();
}

class FakeConnectivityChecker implements NetworkConnectivityChecker {
  @override
  Future<bool> isConnected() async => true;

  @override
  Future<bool> isWifiConnected() async => true;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(true);
}

void main() {
  group('Simulação de Integração Hermética: Release Hardening & Conformidade de Lojas (v1.0.0)', () {
    late Database db;
    late DatabaseManager dbManager;
    late PoiRepository repository;
    late ReleaseHardeningService hardeningService;
    late SystemDiagnosticsService diagnosticsService;

    setUp(() {
      db = sqlite3.openInMemory();
      dbManager = DatabaseManager(db);
      dbManager.initializeSchema();

      // Insere POI de teste
      dbManager.insertPoi(const PoiPoint(
        id: 1,
        latitude: -23.5505,
        longitude: -46.6333,
        type: PoiType.fixedRadar,
        speedLimit: 60,
        roadName: 'Av. 23 de Maio',
      ));

      repository = PoiRepository(dbManager);
      hardeningService = ReleaseHardeningService(
        appVersion: '1.0.0+1',
        applicationId: 'br.com.sentinela.sentinela',
      );
      diagnosticsService = SystemDiagnosticsService(
        locationService: FakeLocationService(),
        repository: repository,
        dbManager: dbManager,
        connectivityChecker: FakeConnectivityChecker(),
      );
    });

    tearDown(() {
      db.close();
    });

    test('Cenário Completo: Auditoria de Hardening -> Manifestos de Lojas -> Diagnóstico de Saúde v1.0.0', () async {
      // 1. Executa Auditoria de Hardening do Ambiente de Release
      final auditReport = await hardeningService.auditEnvironment(
        isReleaseModeOverride: true,
        hasDatabaseOverride: true,
        databaseSizeBytesOverride: 18 * 1024 * 1024, // 18 MB
      );

      expect(auditReport.isProductionReady, isTrue);
      expect(auditReport.criticalFailuresCount, 0);
      expect(auditReport.complianceScore, 100.0);
      expect(auditReport.appVersion, '1.0.0+1');
      expect(auditReport.applicationId, 'br.com.sentinela.sentinela');

      // 2. Valida Conformidade com Apple Privacy Manifest (iOS 17+)
      final appleManifest = hardeningService.generateApplePrivacyManifest();
      expect(appleManifest['NSPrivacyTracking'], isFalse);
      expect(appleManifest['NSPrivacyTrackingDomains'], isEmpty);
      expect(appleManifest['NSPrivacyCollectedDataTypes'], isEmpty);

      final accessedApis = appleManifest['NSPrivacyAccessedAPITypes'] as List<Map<String, dynamic>>;
      expect(accessedApis.any((api) => api['NSPrivacyAccessedAPIType'] == 'NSPrivacyAccessedAPITypeUserDefaults'), isTrue);
      expect(accessedApis.any((api) => api['NSPrivacyAccessedAPIType'] == 'NSPrivacyAccessedAPITypeSystemBootTime'), isTrue);
      expect(accessedApis.any((api) => api['NSPrivacyAccessedAPIType'] == 'NSPrivacyAccessedAPITypeFileTimestamp'), isTrue);

      // 3. Valida Conformidade com Google Play Data Safety (Android)
      final googlePlaySafety = hardeningService.generateGooglePlayDataSafety();
      expect(googlePlaySafety['dataCollected'], isFalse);
      expect(googlePlaySafety['dataShared'], isFalse);
      expect(googlePlaySafety['ephemeralProcessing'], isTrue);
      expect(googlePlaySafety['locationTransferredOffDevice'], isFalse);

      // 4. Valida Diagnóstico de Subsistemas em Produção
      final diagReport = await diagnosticsService.runDiagnostics();
      expect(diagReport.isReadyForNavigation, isTrue);
      expect(diagReport.isDatabaseHealthy, isTrue);
      expect(diagReport.totalPoisIndexed, 1);
      expect(diagReport.isGpsHardwareEnabled, isTrue);
      expect(diagReport.gpsPermission, LocationPermissionStatus.always);
    });
  });
}
