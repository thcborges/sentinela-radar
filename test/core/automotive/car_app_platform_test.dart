import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/automotive/car_app_models.dart';
import 'package:sentinela/core/automotive/car_app_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CarAppPlatformInterface & Adapters (BDD - Testes de Plataforma Automotiva)', () {
    test('FakeCarAppPlatform deve gerenciar sessões, dados e ações em memória', () async {
      final fake = FakeCarAppPlatform();

      expect(await fake.isAvailable(), isTrue);
      expect(await fake.getConnectionStatus(), CarConnectionStatus.disconnected);

      // Simula conexão com Android Auto
      fake.setSimulatedConnectionStatus(CarConnectionStatus.connectedAndroidAuto);
      expect(await fake.getConnectionStatus(), CarConnectionStatus.connectedAndroidAuto);

      // Inicia sessão e envia dados
      expect(await fake.startSession(), isTrue);
      expect(fake.isSessionActive, isTrue);

      const testData = CarAppData(
        currentSpeedKmh: 65,
        speedLimitKmh: 60,
        connectionStatus: CarConnectionStatus.connectedAndroidAuto,
      );
      expect(await fake.updateDisplay(testData), isTrue);
      expect(fake.lastData, equals(testData));

      // Dispara ação simulada do volante / tela
      CarAction? receivedAction;
      fake.setActionHandler((action) {
        receivedAction = action;
      });
      fake.simulateCarAction(CarAction.quickReportRadar);
      expect(receivedAction, CarAction.quickReportRadar);

      // Encerra sessão
      expect(await fake.stopSession(), isTrue);
      expect(fake.isSessionActive, isFalse);
    });

    test('PlatformCarAppAdapter deve interagir com MethodChannel e tratar exceções com segurança', () async {
      const channel = MethodChannel('sentinela/car_app');
      final calls = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call);
        if (call.method == 'isAvailable') return true;
        if (call.method == 'getConnectionStatus') return 'connectedCarPlay';
        if (call.method == 'startSession') return true;
        if (call.method == 'updateDisplay') return true;
        if (call.method == 'stopSession') return true;
        return null;
      });

      final adapter = PlatformCarAppAdapter();

      expect(await adapter.isAvailable(), isTrue);
      expect(await adapter.getConnectionStatus(), CarConnectionStatus.connectedCarPlay);

      const testData = CarAppData(
        currentSpeedKmh: 90,
        connectionStatus: CarConnectionStatus.connectedCarPlay,
      );
      expect(await adapter.startSession(), isTrue);
      expect(await adapter.updateDisplay(testData), isTrue);
      expect(await adapter.stopSession(), isTrue);

      expect(calls.map((c) => c.method), [
        'isAvailable',
        'getConnectionStatus',
        'startSession',
        'updateDisplay',
        'stopSession',
      ]);
    });

    test('PlatformCarAppAdapter deve retornar fallbacks seguros se o canal lançar PlatformException', () async {
      const channel = MethodChannel('sentinela/car_app');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        throw PlatformException(code: 'UNAVAILABLE', message: 'Car subsystem offline');
      });

      final adapter = PlatformCarAppAdapter();

      expect(await adapter.isAvailable(), isFalse);
      expect(await adapter.getConnectionStatus(), CarConnectionStatus.disconnected);
      expect(await adapter.startSession(), isFalse);
      expect(await adapter.updateDisplay(const CarAppData()), isFalse);
      expect(await adapter.stopSession(), isFalse);
    });

    test('PlatformCarAppAdapter deve despachar onCarAction enviado pelo canal nativo', () async {
      final adapter = PlatformCarAppAdapter();
      CarAction? actionFromNative;
      adapter.setActionHandler((action) {
        actionFromNative = action;
      });

      final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await binding.handlePlatformMessage(
        'sentinela/car_app',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onCarAction', 'quickReportRadar')),
        (ByteData? data) {},
      );

      expect(actionFromNative, CarAction.quickReportRadar);

      // Chamada sem argumento não deve crashar
      await binding.handlePlatformMessage(
        'sentinela/car_app',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onCarAction', null)),
        (ByteData? data) {},
      );

      // Chamada de método desconhecido
      await binding.handlePlatformMessage(
        'sentinela/car_app',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('otherMethod', null)),
        (ByteData? data) {},
      );
    });

    test('FakeCarAppPlatform dispose deve fechar stream sem erros', () {
      final fake = FakeCarAppPlatform();
      expect(() => fake.dispose(), returnsNormally);
    });
  });
}
