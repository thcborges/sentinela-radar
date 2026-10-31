import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/automotive/automotive_service.dart';
import 'package:sentinela/core/automotive/car_app_models.dart';
import 'package:sentinela/core/automotive/car_app_platform_interface.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutomotiveService (BDD - Orquestrador Android Auto & CarPlay)', () {
    late FakeCarAppPlatform fakePlatform;
    late AutomotiveService service;

    setUp(() {
      fakePlatform = FakeCarAppPlatform();
      service = AutomotiveService(platform: fakePlatform);
    });

    tearDown(() {
      service.dispose();
    });

    test('deve iniciar sessão automaticamente quando a central automotiva for conectada', () async {
      expect(service.isConnected, isFalse);

      fakePlatform.setSimulatedConnectionStatus(CarConnectionStatus.connectedAndroidAuto);
      await pumpEventQueue();

      expect(service.isConnected, isTrue);
      expect(service.currentConnection, CarConnectionStatus.connectedAndroidAuto);
      expect(fakePlatform.isSessionActive, isTrue);
    });

    test('deve atualizar display automotivo ao receber telemetria veicular e alerta', () async {
      fakePlatform.setSimulatedConnectionStatus(CarConnectionStatus.connectedCarPlay);
      await pumpEventQueue();

      final pos = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 75.0,
        bearing: 180.0,
        accuracyMeters: 5,
        timestamp: DateTime(2026, 10, 31, 14, 0),
      );

      const alert = ActiveAlert(
        poi: PoiPoint(id: 1, latitude: -23.552, longitude: -46.6333, type: PoiType.fixedRadar, speedLimit: 60),
        distanceMeters: 170,
        currentSpeedKmh: 75,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 180,
        relativeBearing: 0,
      );

      await service.updateWithPosition(
        position: pos,
        roadName: 'Corredor Norte-Sul',
        activeAlert: alert,
        alertStatus: AlertStatus.overSpeed,
        isNightMode: true,
      );

      final displayData = fakePlatform.lastData;
      expect(displayData, isNotNull);
      expect(displayData!.currentSpeedKmh, 75.0);
      expect(displayData.speedLimitKmh, 60);
      expect(displayData.roadName, 'Corredor Norte-Sul');
      expect(displayData.alertStatus, AlertStatus.overSpeed);
      expect(displayData.isNightMode, isTrue);
    });

    test('deve aplicar restrições de distração do motorista (Driver Distraction Guidelines)', () async {
      fakePlatform.setSimulatedConnectionStatus(CarConnectionStatus.connectedAndroidAuto);
      await pumpEventQueue();

      // Em alta velocidade (> 80 km/h): apenas ações críticas permitidas (máx 2 ações)
      final highSpeedPos = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 110.0,
        bearing: 0,
        accuracyMeters: 5,
        timestamp: DateTime(2026, 10, 31, 14, 0),
      );

      await service.updateWithPosition(
        position: highSpeedPos,
        roadName: 'Rodovia dos Imigrantes',
      );

      final data = fakePlatform.lastData;
      expect(data, isNotNull);
      expect(data!.distractionLevel, CarDistractionLevel.highSpeed);
      expect(data.allowedActions.length, lessThanOrEqualTo(2));
    });

    test('deve repassar ações do volante para o callback registrado', () async {
      fakePlatform.setSimulatedConnectionStatus(CarConnectionStatus.connectedAndroidAuto);
      await pumpEventQueue();

      CarAction? executedAction;
      service.onCarAction = (action) {
        executedAction = action;
      };

      fakePlatform.simulateCarAction(CarAction.quickReportRadar);
      expect(executedAction, CarAction.quickReportRadar);
    });

    test('deve encerrar sessão automotiva ao desconectar ou chamar dispose', () async {
      fakePlatform.setSimulatedConnectionStatus(CarConnectionStatus.connectedAndroidAuto);
      await pumpEventQueue();
      expect(fakePlatform.isSessionActive, isTrue);

      fakePlatform.setSimulatedConnectionStatus(CarConnectionStatus.disconnected);
      await pumpEventQueue();
      expect(fakePlatform.isSessionActive, isFalse);
      expect(service.isConnected, isFalse);
    });

    test('deve limitar sonarItems a 3 elementos e expor getters de estado', () async {
      fakePlatform.setSimulatedConnectionStatus(CarConnectionStatus.connectedCarPlay);
      await pumpEventQueue();

      final pos = VehiclePosition(
        latitude: -23.55,
        longitude: -46.63,
        speedKmh: 3.0, // Parked
        bearing: 0,
        accuracyMeters: 5,
        timestamp: DateTime.now(),
      );

      final items = [
        const CarSonarItem(label: 'POI 1', distanceMeters: 100, relativeAngleDeg: 0, poiType: PoiType.fixedRadar, isCritical: false),
        const CarSonarItem(label: 'POI 2', distanceMeters: 200, relativeAngleDeg: 10, poiType: PoiType.fixedRadar, isCritical: false),
        const CarSonarItem(label: 'POI 3', distanceMeters: 300, relativeAngleDeg: -10, poiType: PoiType.fixedRadar, isCritical: false),
        const CarSonarItem(label: 'POI 4', distanceMeters: 400, relativeAngleDeg: 20, poiType: PoiType.fixedRadar, isCritical: false),
      ];

      final success = await service.updateWithPosition(
        position: pos,
        sonarItems: items,
        isMuted: true,
      );

      expect(success, isTrue);
      expect(service.lastData.simplifiedSonarItems.length, 3);
      expect(service.lastData.distractionLevel, CarDistractionLevel.parked);
      expect(service.platform, equals(fakePlatform));

      // Teste desconectado retorna false
      fakePlatform.setSimulatedConnectionStatus(CarConnectionStatus.disconnected);
      await pumpEventQueue();
      final disconnectedResult = await service.updateWithPosition(position: pos);
      expect(disconnectedResult, isFalse);
    });

    test('AutomotiveService com adaptador padrão deve instanciar PlatformCarAppAdapter', () {
      final defaultService = AutomotiveService();
      expect(defaultService.platform, isA<PlatformCarAppAdapter>());
      defaultService.dispose();
    });
  });
}
