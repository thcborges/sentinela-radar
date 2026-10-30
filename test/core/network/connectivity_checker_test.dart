import 'dart:async';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/network/connectivity_checker.dart';

class MockConnectivityPlatform extends Mock implements ConnectivityPlatform {}

class FakeConnectivityChecker implements NetworkConnectivityChecker {
  bool connected = true;
  bool wifi = true;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isConnected() async => connected;

  @override
  Future<bool> isWifiConnected() async => wifi;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void emit(bool state) => _controller.add(state);
  void dispose() => _controller.close();
}

void main() {
  group('NetworkConnectivityChecker Tests (BDD)', () {
    test('FakeConnectivityChecker deve reportar status e emitir eventos', () async {
      final fake = FakeConnectivityChecker();
      expect(await fake.isConnected(), isTrue);
      expect(await fake.isWifiConnected(), isTrue);

      fake.wifi = false;
      fake.connected = true;
      expect(await fake.isWifiConnected(), isFalse);
      expect(await fake.isConnected(), isTrue);

      final events = <bool>[];
      final sub = fake.onConnectivityChanged.listen(events.add);

      fake.emit(false);
      fake.emit(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(events, equals([false, true]));
      await sub.cancel();
      fake.dispose();
    });

    test('PlatformConnectivityChecker deve detectar conexão Wi-Fi e dados móveis', () async {
      final mock = MockConnectivityPlatform();
      final checker = PlatformConnectivityChecker(platform: mock);

      when(() => mock.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);
      expect(await checker.isConnected(), isTrue);
      expect(await checker.isWifiConnected(), isTrue);

      when(() => mock.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.mobile]);
      expect(await checker.isConnected(), isTrue);
      expect(await checker.isWifiConnected(), isFalse);

      when(() => mock.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);
      expect(await checker.isConnected(), isFalse);
      expect(await checker.isWifiConnected(), isFalse);
    });

    test('PlatformConnectivityChecker deve tratar erros de plataforma', () async {
      final mock = MockConnectivityPlatform();
      final checker = PlatformConnectivityChecker(platform: mock);

      when(() => mock.checkConnectivity()).thenThrow(Exception('Platform error'));
      expect(await checker.isConnected(), isFalse);
      expect(await checker.isWifiConnected(), isFalse);
    });

    test('PlatformConnectivityChecker onConnectivityChanged deve mapear stream', () async {
      final mock = MockConnectivityPlatform();
      final streamController = StreamController<List<ConnectivityResult>>();
      when(() => mock.onConnectivityChanged)
          .thenAnswer((_) => streamController.stream);

      final checker = PlatformConnectivityChecker(platform: mock);
      final events = <bool>[];
      final sub = checker.onConnectivityChanged.listen(events.add);

      streamController.add([ConnectivityResult.wifi]);
      streamController.add([ConnectivityResult.none]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(events, equals([true, false]));

      await sub.cancel();
      await streamController.close();
    });

    test('PlatformConnectivityChecker construtor padrão sem mock deve instanciar', () {
      final checker = PlatformConnectivityChecker();
      expect(checker, isNotNull);
    });
  });
}
