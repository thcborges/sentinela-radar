import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/diagnostics/system_diagnostics.dart';
import 'package:sentinela/core/location/location_service_interface.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/network/connectivity_checker.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/data/repository/poi_repository.dart';

class MockLocationService extends Mock implements LocationService {}
class MockPoiRepository extends Mock implements PoiRepository {}
class MockDatabaseManager extends Mock implements DatabaseManager {}
class MockConnectivityChecker extends Mock implements NetworkConnectivityChecker {}

void main() {
  group('SystemDiagnosticsService Tests (BDD)', () {
    late MockLocationService mockLocation;
    late MockPoiRepository mockRepo;
    late MockDatabaseManager mockDbManager;
    late MockConnectivityChecker mockConn;
    late SystemDiagnosticsService diagnosticsService;

    setUp(() {
      mockLocation = MockLocationService();
      mockRepo = MockPoiRepository();
      mockDbManager = MockDatabaseManager();
      mockConn = MockConnectivityChecker();

      diagnosticsService = SystemDiagnosticsService(
        locationService: mockLocation,
        repository: mockRepo,
        dbManager: mockDbManager,
        connectivityChecker: mockConn,
      );
    });

    test('deve reportar status pronto quando todos os subsistemas estiverem saudáveis', () async {
      when(() => mockLocation.isLocationServiceEnabled()).thenAnswer((_) async => true);
      when(() => mockLocation.checkPermission())
          .thenAnswer((_) async => LocationPermissionStatus.whileInUse);
      when(() => mockDbManager.getTotalCount()).thenReturn(70000);
      when(() => mockRepo.findNearbyPois(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          )).thenAnswer((_) async => [
            const PoiPoint(id: 1, type: PoiType.fixedRadar, latitude: 0, longitude: 0),
          ]);
      when(() => mockConn.isConnected()).thenAnswer((_) async => true);
      when(() => mockConn.isWifiConnected()).thenAnswer((_) async => true);

      final report = await diagnosticsService.runDiagnostics();

      expect(report.isGpsHardwareEnabled, isTrue);
      expect(report.gpsPermission, equals(LocationPermissionStatus.whileInUse));
      expect(report.isDatabaseHealthy, isTrue);
      expect(report.totalPoisIndexed, equals(70000));
      expect(report.isNetworkConnected, isTrue);
      expect(report.isWifiConnected, isTrue);
      expect(report.isReadyForNavigation, isTrue);
      expect(report.summaryMessage, contains('Sistema 100% operacional'));
    });

    test('deve detectar falha quando o GPS estiver desativado ou sem permissão', () async {
      when(() => mockLocation.isLocationServiceEnabled()).thenAnswer((_) async => false);
      when(() => mockLocation.checkPermission())
          .thenAnswer((_) async => LocationPermissionStatus.denied);
      when(() => mockDbManager.getTotalCount()).thenReturn(5000);
      when(() => mockRepo.findNearbyPois(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          )).thenAnswer((_) async => []);
      when(() => mockConn.isConnected()).thenAnswer((_) async => false);
      when(() => mockConn.isWifiConnected()).thenAnswer((_) async => false);

      final report = await diagnosticsService.runDiagnostics();

      expect(report.isGpsHardwareEnabled, isFalse);
      expect(report.isReadyForNavigation, isFalse);
      expect(report.summaryMessage, contains('GPS'));
    });

    test('deve calcular tamanho do banco se arquivo existir no disco', () async {
      final tempDir = await Directory.systemTemp.createTemp('diag_test_');
      final dbFile = File('${tempDir.path}/test.db');
      dbFile.writeAsBytesSync(List.filled(1024 * 1024 * 2, 0)); // 2 MB

      when(() => mockLocation.isLocationServiceEnabled()).thenAnswer((_) async => true);
      when(() => mockLocation.checkPermission())
          .thenAnswer((_) async => LocationPermissionStatus.always);
      when(() => mockDbManager.getTotalCount()).thenReturn(10);
      when(() => mockRepo.findNearbyPois(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          )).thenAnswer((_) async => []);
      when(() => mockConn.isConnected()).thenAnswer((_) async => true);
      when(() => mockConn.isWifiConnected()).thenAnswer((_) async => false);

      final report = await diagnosticsService.runDiagnostics(dbFilePath: dbFile.path);
      expect(report.databaseSizeMb, closeTo(2.0, 0.1));

      tempDir.deleteSync(recursive: true);
    });

    test('DiagnosticReport deve ter suporte a Equatable props', () {
      const r1 = DiagnosticReport(
        isGpsHardwareEnabled: true,
        gpsPermission: LocationPermissionStatus.always,
        isDatabaseHealthy: true,
        totalPoisIndexed: 100,
        databaseSizeMb: 1.5,
        isNetworkConnected: true,
        isWifiConnected: true,
        isReadyForNavigation: true,
        summaryMessage: 'OK',
      );
      const r2 = DiagnosticReport(
        isGpsHardwareEnabled: true,
        gpsPermission: LocationPermissionStatus.always,
        isDatabaseHealthy: true,
        totalPoisIndexed: 100,
        databaseSizeMb: 1.5,
        isNetworkConnected: true,
        isWifiConnected: true,
        isReadyForNavigation: true,
        summaryMessage: 'OK',
      );

      expect(r1, equals(r2));
      expect(r1.props, equals(r2.props));
    });
  });
}
