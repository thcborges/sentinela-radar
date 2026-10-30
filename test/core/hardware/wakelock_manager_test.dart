import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/hardware/wakelock_manager.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class MockWakelockPlatform extends Mock implements WakelockPlusPlatformInterface {}

class FakeWakelockManager implements WakelockManager {
  bool _enabled = false;

  @override
  Future<void> enable() async {
    _enabled = true;
  }

  @override
  Future<void> disable() async {
    _enabled = false;
  }

  @override
  Future<bool> isEnabled() async => _enabled;
}

void main() {
  group('WakelockManager Tests (BDD)', () {
    test('FakeWakelockManager deve alternar estado ligado/desligado', () async {
      final manager = FakeWakelockManager();
      expect(await manager.isEnabled(), isFalse);

      await manager.enable();
      expect(await manager.isEnabled(), isTrue);

      await manager.disable();
      expect(await manager.isEnabled(), isFalse);
    });

    test('PlatformWakelockManager com Mock Platform deve delegar chamadas', () async {
      final mockPlatform = MockWakelockPlatform();
      final manager = PlatformWakelockManager(platform: mockPlatform);

      when(() => mockPlatform.toggle(enable: true)).thenAnswer((_) async {});
      when(() => mockPlatform.toggle(enable: false)).thenAnswer((_) async {});
      when(() => mockPlatform.enabled).thenAnswer((_) async => true);

      await manager.enable();
      verify(() => mockPlatform.toggle(enable: true)).called(1);

      expect(await manager.isEnabled(), isTrue);

      await manager.disable();
      verify(() => mockPlatform.toggle(enable: false)).called(1);
    });

    test('PlatformWakelockManager deve tratar erros de plataforma graciosamente', () async {
      final mockPlatform = MockWakelockPlatform();
      final manager = PlatformWakelockManager(platform: mockPlatform);

      when(() => mockPlatform.toggle(enable: any(named: 'enable')))
          .thenThrow(Exception('Headless environment'));
      when(() => mockPlatform.enabled).thenThrow(Exception('Platform error'));

      // Não deve lançar exceção
      await manager.enable();
      await manager.disable();
      expect(await manager.isEnabled(), isFalse);
    });

    test('PlatformWakelockManager construtor padrão sem mock deve instanciar com sucesso', () {
      final manager = PlatformWakelockManager();
      expect(manager, isNotNull);
    });
  });
}
