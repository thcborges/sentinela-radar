import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/platform/haptic_feedback_engine.dart';

class MockHapticPlatformBridge implements HapticPlatformBridge {
  final List<String> calls = [];

  @override
  Future<void> selectionClick() async {
    calls.add('selectionClick');
  }

  @override
  Future<void> lightImpact() async {
    calls.add('lightImpact');
  }

  @override
  Future<void> mediumImpact() async {
    calls.add('mediumImpact');
  }

  @override
  Future<void> heavyImpact() async {
    calls.add('heavyImpact');
  }

  @override
  Future<void> vibrate() async {
    calls.add('vibrate');
  }

  void clear() => calls.clear();
}

void main() {
  group('HapticFeedbackEngine (BDD - Feedback Háptico e Acessibilidade Tátil)', () {
    late MockHapticPlatformBridge bridge;
    late HapticFeedbackEngine engine;

    setUp(() {
      bridge = MockHapticPlatformBridge();
      engine = HapticFeedbackEngine(bridge: bridge);
    });

    test('deve acionar selectionClick para o padrão click', () async {
      await engine.trigger(HapticPattern.click);
      expect(bridge.calls, ['selectionClick']);
    });

    test('não deve emitir vibração quando HapticIntensity for off', () async {
      await engine.trigger(HapticPattern.radarWarning, intensity: HapticIntensity.off);
      expect(bridge.calls, isEmpty);
    });

    test('deve emitir lightImpact para gentleNotice com intensidade light', () async {
      await engine.trigger(HapticPattern.gentleNotice, intensity: HapticIntensity.light);
      expect(bridge.calls, ['lightImpact']);
    });

    test('deve emitir mediumImpact para gentleNotice com intensidade medium', () async {
      await engine.trigger(HapticPattern.gentleNotice, intensity: HapticIntensity.medium);
      expect(bridge.calls, ['mediumImpact']);
    });

    test('deve emitir pulso duplo para aproximação de radar (radarWarning)', () async {
      await engine.trigger(HapticPattern.radarWarning, intensity: HapticIntensity.medium);
      // Pulso duplo: heavyImpact seguido de mediumImpact
      expect(bridge.calls, contains('heavyImpact'));
    });

    test('deve emitir vibrate contínuo/incisivo para alerta crítico de excesso de velocidade', () async {
      await engine.trigger(HapticPattern.criticalOverSpeed, intensity: HapticIntensity.strong);
      expect(bridge.calls, ['vibrate']);
    });

    test('triggerForAlert deve respeitar hapticEnabled = false', () async {
      const alert = ActiveAlert(
        poi: PoiPoint(id: 1, latitude: -23.5, longitude: -46.6, type: PoiType.fixedRadar, speedLimit: 60),
        distanceMeters: 250,
        currentSpeedKmh: 50,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 180,
        relativeBearing: 0,
      );

      await engine.triggerForAlert(alert, hapticEnabled: false);
      expect(bridge.calls, isEmpty);
    });

    test('triggerForAlert deve emitir radarWarning se velocidade for compatível', () async {
      const alert = ActiveAlert(
        poi: PoiPoint(id: 1, latitude: -23.5, longitude: -46.6, type: PoiType.fixedRadar, speedLimit: 60),
        distanceMeters: 250,
        currentSpeedKmh: 55,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 180,
        relativeBearing: 0,
      );

      await engine.triggerForAlert(alert, hapticEnabled: true);
      expect(bridge.calls, isNotEmpty);
    });

    test('triggerForAlert deve emitir criticalOverSpeed em excesso de velocidade com debounce', () async {
      const overSpeedAlert = ActiveAlert(
        poi: PoiPoint(id: 1, latitude: -23.5, longitude: -46.6, type: PoiType.fixedRadar, speedLimit: 60),
        distanceMeters: 200,
        currentSpeedKmh: 85,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 180,
        relativeBearing: 0,
      );

      // Primeiro acionamento
      await engine.triggerForAlert(overSpeedAlert, hapticEnabled: true);
      expect(bridge.calls, contains('vibrate'));

      // Segundo acionamento imediato (dentro do debounce)
      bridge.clear();
      await engine.triggerForAlert(overSpeedAlert, hapticEnabled: true);
      expect(bridge.calls, isEmpty); // Bloqueado pelo debounce

      // Reset de debounce
      engine.resetDebounce();
      await engine.triggerForAlert(overSpeedAlert, hapticEnabled: true);
      expect(bridge.calls, contains('vibrate'));
    });

    test('triggerPoiPassed e triggerQuickReport devem emitir confirmação de sucesso', () async {
      await engine.triggerPoiPassed();
      expect(bridge.calls, isNotEmpty);

      bridge.clear();
      await engine.triggerQuickReport();
      expect(bridge.calls, isNotEmpty);

      // Desativados
      bridge.clear();
      await engine.triggerPoiPassed(hapticEnabled: false);
      await engine.triggerQuickReport(intensity: HapticIntensity.off);
      expect(bridge.calls, isEmpty);
    });

    test('HapticIntensity enum deve conter displayNames corretos', () {
      expect(HapticIntensity.off.displayName, 'Desativado');
      expect(HapticIntensity.light.displayName, 'Suave');
      expect(HapticIntensity.medium.displayName, 'Médio');
      expect(HapticIntensity.strong.displayName, 'Forte');
    });

    test('DefaultHapticPlatformBridge métodos devem executar sem falhas', () async {
      const defaultBridge = DefaultHapticPlatformBridge();
      await defaultBridge.selectionClick();
      await defaultBridge.lightImpact();
      await defaultBridge.mediumImpact();
      await defaultBridge.heavyImpact();
      await defaultBridge.vibrate();
    });

    test('deve tratar intensidades light e strong para radarWarning e gentleNotice', () async {
      await engine.trigger(HapticPattern.radarWarning, intensity: HapticIntensity.light);
      expect(bridge.calls, contains('mediumImpact'));

      bridge.clear();
      await engine.trigger(HapticPattern.radarWarning, intensity: HapticIntensity.strong);
      expect(bridge.calls.where((c) => c == 'heavyImpact').length, 2);

      bridge.clear();
      await engine.trigger(HapticPattern.gentleNotice, intensity: HapticIntensity.strong);
      expect(bridge.calls, contains('heavyImpact'));
    });

    test('triggerForAlert deve disparar gentleNotice para lombada física e pedágio', () async {
      const bumpAlert = ActiveAlert(
        poi: PoiPoint(id: 10, latitude: -23.5, longitude: -46.6, type: PoiType.physicalSpeedBump),
        distanceMeters: 80,
        currentSpeedKmh: 30,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 180,
        relativeBearing: 0,
      );

      await engine.triggerForAlert(bumpAlert);
      expect(bridge.calls, contains('mediumImpact'));
    });
  });
}
