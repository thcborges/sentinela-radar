import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/platform/live_activity_service.dart';

class MockLiveActivityPlatform extends Mock implements LiveActivityPlatformInterface {}

void main() {
  group('LiveActivityService Tests (BDD - Dynamic Island / Lock Screen)', () {
    late MockLiveActivityPlatform mockPlatform;
    late LiveActivityService service;

    setUpAll(() {
      registerFallbackValue(const LiveActivityData(
        currentSpeedKmh: 60.0,
        speedLimitKmh: 60,
        alertStatus: AlertStatus.idle,
        isAlertActive: false,
      ));
    });

    setUp(() {
      mockPlatform = MockLiveActivityPlatform();
      service = LiveActivityService(platform: mockPlatform);
    });

    test('isSupported deve consultar a plataforma', () async {
      when(() => mockPlatform.isSupported()).thenAnswer((_) async => true);

      final supported = await service.isSupported();
      expect(supported, isTrue);
      verify(() => mockPlatform.isSupported()).called(1);
    });

    test('startActivity deve iniciar Live Activity quando plataforma suportar', () async {
      when(() => mockPlatform.isSupported()).thenAnswer((_) async => true);
      when(() => mockPlatform.startActivity(any())).thenAnswer((_) async => true);

      const data = LiveActivityData(
        currentSpeedKmh: 75.0,
        speedLimitKmh: 60,
        alertStatus: AlertStatus.overSpeed,
        poiType: PoiType.fixedRadar,
        distanceMeters: 250.0,
        roadName: 'Av. Paulista',
        isAlertActive: true,
      );

      final result = await service.startActivity(data);
      expect(result, isTrue);
      expect(service.isActive, isTrue);
      verify(() => mockPlatform.startActivity(data)).called(1);
    });

    test('updateActivity deve atualizar Live Activity ativa', () async {
      when(() => mockPlatform.isSupported()).thenAnswer((_) async => true);
      when(() => mockPlatform.startActivity(any())).thenAnswer((_) async => true);
      when(() => mockPlatform.updateActivity(any())).thenAnswer((_) async => true);

      const initialData = LiveActivityData(
        currentSpeedKmh: 60.0,
        speedLimitKmh: 60,
        alertStatus: AlertStatus.approaching,
        isAlertActive: true,
      );
      await service.startActivity(initialData);

      const updatedData = LiveActivityData(
        currentSpeedKmh: 65.0,
        speedLimitKmh: 60,
        alertStatus: AlertStatus.overSpeed,
        isAlertActive: true,
      );
      final updateResult = await service.updateActivity(updatedData);

      expect(updateResult, isTrue);
      expect(service.currentData, equals(updatedData));
      verify(() => mockPlatform.updateActivity(updatedData)).called(1);
    });

    test('stopActivity deve encerrar Live Activity e limpar estado', () async {
      when(() => mockPlatform.isSupported()).thenAnswer((_) async => true);
      when(() => mockPlatform.startActivity(any())).thenAnswer((_) async => true);
      when(() => mockPlatform.stopActivity()).thenAnswer((_) async => true);

      await service.startActivity(const LiveActivityData(
        currentSpeedKmh: 50.0,
        speedLimitKmh: 60,
        alertStatus: AlertStatus.idle,
        isAlertActive: false,
      ));

      final stopped = await service.stopActivity();
      expect(stopped, isTrue);
      expect(service.isActive, isFalse);
      expect(service.currentData, isNull);
      verify(() => mockPlatform.stopActivity()).called(1);
    });

    test('LiveActivityData deve suportar igualdade por valor via Equatable', () {
      const dataA = LiveActivityData(
        currentSpeedKmh: 80.0,
        speedLimitKmh: 80,
        alertStatus: AlertStatus.approaching,
        poiType: PoiType.fixedRadar,
        distanceMeters: 300,
        roadName: 'Rod. dos Bandeirantes',
        isAlertActive: true,
      );

      const dataB = LiveActivityData(
        currentSpeedKmh: 80.0,
        speedLimitKmh: 80,
        alertStatus: AlertStatus.approaching,
        poiType: PoiType.fixedRadar,
        distanceMeters: 300,
        roadName: 'Rod. dos Bandeirantes',
        isAlertActive: true,
      );

      expect(dataA, equals(dataB));
      expect(dataA.props, equals(dataB.props));
    });

    test('FakeLiveActivityPlatform deve simular ciclo de vida sem canais nativos', () async {
      final fake = FakeLiveActivityPlatform();
      expect(await fake.isSupported(), isTrue);

      const data = LiveActivityData(
        currentSpeedKmh: 50,
        alertStatus: AlertStatus.idle,
        isAlertActive: false,
      );
      expect(await fake.startActivity(data), isTrue);
      expect(fake.lastData, equals(data));

      const updated = LiveActivityData(
        currentSpeedKmh: 70,
        alertStatus: AlertStatus.alerting,
        isAlertActive: true,
      );
      expect(await fake.updateActivity(updated), isTrue);
      expect(fake.lastData, equals(updated));

      expect(await fake.stopActivity(), isTrue);
      expect(fake.lastData, isNull);
    });

    test('PlatformLiveActivityAdapter deve invocar canal de plataforma com sucesso', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final adapter = PlatformLiveActivityAdapter();
      const channel = MethodChannel('sentinela/live_activities');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'isSupported':
            return true;
          case 'startActivity':
            return true;
          case 'updateActivity':
            return true;
          case 'stopActivity':
            return true;
          default:
            return null;
        }
      });

      expect(await adapter.isSupported(), isTrue);

      const data = LiveActivityData(
        currentSpeedKmh: 80,
        alertStatus: AlertStatus.approaching,
        isAlertActive: true,
      );
      expect(await adapter.startActivity(data), isTrue);
      expect(await adapter.updateActivity(data), isTrue);
      expect(await adapter.stopActivity(), isTrue);
    });

    test('PlatformLiveActivityAdapter deve tratar exceções de plataforma retornando false', () async {
      final adapter = PlatformLiveActivityAdapter();
      const channel = MethodChannel('sentinela/live_activities');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        throw PlatformException(code: 'ERROR', message: 'Falha');
      });

      expect(await adapter.isSupported(), isFalse);

      const data = LiveActivityData(
        currentSpeedKmh: 80,
        alertStatus: AlertStatus.approaching,
        isAlertActive: true,
      );
      expect(await adapter.startActivity(data), isFalse);
      expect(await adapter.updateActivity(data), isFalse);
      expect(await adapter.stopActivity(), isFalse);
    });
  });
}
