import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/core/models/poi_model.dart';

void main() {
  group('AlertPreferences Tests (BDD - Tolerância e Parâmetros Customizados)', () {
    test('Valores padrão devem ter tolerância zero e antecipação de 15s', () {
      const prefs = AlertPreferences();
      expect(prefs.speedToleranceKmh, equals(0.0));
      expect(prefs.speedTolerancePercent, equals(0.0));
      expect(prefs.alertOnlyIfOverSpeed, isFalse);
      expect(prefs.anticipationTimeSeconds, equals(15.0));
      expect(prefs.soundEnabled, isTrue);
      expect(prefs.voiceEnabled, isTrue);
    });

    test('isOverSpeed sem tolerância deve acusar excesso acima do limite estrito', () {
      const prefs = AlertPreferences();
      expect(prefs.isOverSpeed(60.0, 60), isFalse);
      expect(prefs.isOverSpeed(60.1, 60), isTrue);
      expect(prefs.isOverSpeed(55.0, 60), isFalse);
      expect(prefs.isOverSpeed(100.0, null), isFalse);
    });

    test('isOverSpeed com tolerância fixa em km/h (+5 km/h)', () {
      const prefs = AlertPreferences(speedToleranceKmh: 5.0);
      expect(prefs.isOverSpeed(60.0, 60), isFalse);
      expect(prefs.isOverSpeed(64.9, 60), isFalse);
      expect(prefs.isOverSpeed(65.0, 60), isFalse);
      expect(prefs.isOverSpeed(65.1, 60), isTrue);
    });

    test('isOverSpeed com tolerância percentual (+10%)', () {
      const prefs = AlertPreferences(speedTolerancePercent: 0.10);
      // Limite 80 km/h + 10% = 88 km/h
      expect(prefs.isOverSpeed(85.0, 80), isFalse);
      expect(prefs.isOverSpeed(88.0, 80), isFalse);
      expect(prefs.isOverSpeed(88.5, 80), isTrue);
    });

    test('copyWith deve permitir atualização imutável parcial', () {
      const prefs = AlertPreferences();
      final updated = prefs.copyWith(
        speedToleranceKmh: 7.0,
        alertOnlyIfOverSpeed: true,
        anticipationTimeSeconds: 20.0,
      );

      expect(updated.speedToleranceKmh, equals(7.0));
      expect(updated.alertOnlyIfOverSpeed, isTrue);
      expect(updated.anticipationTimeSeconds, equals(20.0));
      expect(updated.soundEnabled, isTrue);
    });

    test('toJson e fromJson devem serializar e desserializar com precisão', () {
      const original = AlertPreferences(
        speedToleranceKmh: 5.0,
        speedTolerancePercent: 0.05,
        alertOnlyIfOverSpeed: true,
        anticipationTimeSeconds: 18.0,
        soundEnabled: false,
        voiceEnabled: true,
      );

      final json = original.toJson();
      final deserialized = AlertPreferences.fromJson(json);

      expect(deserialized, equals(original));
    });

    test('AlertMachine com tolerância customizada deve classificar status com margem', () {
      const customPrefs = AlertPreferences(speedToleranceKmh: 5.0);
      final alertMachine = AlertMachine(preferences: customPrefs);

      const poi = PoiPoint(
        id: 1,
        latitude: -23.5505,
        longitude: -46.6333,
        type: PoiType.fixedRadar,
        speedLimit: 60,
        direction: 0,
      );

      // Carro a 63 km/h (acima de 60, mas dentro dos 60 + 5 km/h tolerados)
      final posWithinTolerance = VehiclePosition(
        latitude: -23.5520,
        longitude: -46.6333,
        speedKmh: 63.0,
        bearing: 0,
        accuracyMeters: 4.0,
        timestamp: DateTime(2026, 1, 1),
      );

      alertMachine.updatePosition(posWithinTolerance, [poi]);

      expect(alertMachine.state.status, equals(AlertStatus.alerting));
      expect(alertMachine.state.activeAlert?.isOverSpeed, isFalse);

      // Carro a 66 km/h (acima da margem de tolerância)
      final posOverTolerance = VehiclePosition(
        latitude: -23.5515,
        longitude: -46.6333,
        speedKmh: 66.0,
        bearing: 0,
        accuracyMeters: 4.0,
        timestamp: DateTime(2026, 1, 1),
      );

      alertMachine.updatePosition(posOverTolerance, [poi]);

      expect(alertMachine.state.status, equals(AlertStatus.overSpeed));
      expect(alertMachine.state.activeAlert?.isOverSpeed, isTrue);

      alertMachine.close();
    });
  });
}
