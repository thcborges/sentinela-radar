import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/audio/tts_alert_formatter.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/l10n/app_language.dart';
import 'package:sentinela/core/models/poi_model.dart';

void main() {
  group('TtsAlertFormatter Multilingual Tests (BDD)', () {
    const fixedRadar60 = PoiPoint(
      id: 1,
      latitude: -23.5,
      longitude: -46.6,
      type: PoiType.fixedRadar,
      speedLimit: 60,
    );

    const tollBooth = PoiPoint(
      id: 2,
      latitude: -23.5,
      longitude: -46.6,
      type: PoiType.tollBooth,
    );

    const normalAlert = ActiveAlert(
      poi: fixedRadar60,
      distanceMeters: 300,
      currentSpeedKmh: 55,
      status: AlertStatus.alerting,
      isOverSpeed: false,
      targetBearing: 180,
      relativeBearing: 0,
    );

    const overSpeedAlert = ActiveAlert(
      poi: fixedRadar60,
      distanceMeters: 250,
      currentSpeedKmh: 80,
      status: AlertStatus.overSpeed,
      isOverSpeed: true,
      targetBearing: 180,
      relativeBearing: 0,
    );

    test('deve formatar alerta em Português (padrão mantido)', () {
      final normal = TtsAlertFormatter.formatSpokenAlert(normalAlert, language: AppLanguage.pt);
      expect(normal, 'Radar fixo, 60 km/h à frente');

      final overSpeed = TtsAlertFormatter.formatSpokenAlert(overSpeedAlert, language: AppLanguage.pt);
      expect(overSpeed, 'Atenção: Reduza a velocidade. Radar fixo, 60 km/h à frente');

      final toll = TtsAlertFormatter.formatPoiAlert(tollBooth, language: AppLanguage.pt);
      expect(toll, 'Praça de pedágio à frente');
    });

    test('deve formatar alerta em Inglês quando especificado', () {
      final normal = TtsAlertFormatter.formatSpokenAlert(normalAlert, language: AppLanguage.en);
      expect(normal, 'Fixed speed camera, 60 km/h ahead');

      final overSpeed = TtsAlertFormatter.formatSpokenAlert(overSpeedAlert, language: AppLanguage.en);
      expect(overSpeed, 'Warning: Reduce your speed. Fixed speed camera, 60 km/h ahead');

      final toll = TtsAlertFormatter.formatPoiAlert(tollBooth, language: AppLanguage.en);
      expect(toll, 'Toll plaza ahead');
    });

    test('deve formatar alerta em Espanhol quando especificado', () {
      final normal = TtsAlertFormatter.formatSpokenAlert(normalAlert, language: AppLanguage.es);
      expect(normal, 'Radar fijo, 60 km/h adelante');

      final overSpeed = TtsAlertFormatter.formatSpokenAlert(overSpeedAlert, language: AppLanguage.es);
      expect(overSpeed, 'Atención: Reduzca la velocidad. Radar fijo, 60 km/h adelante');

      final toll = TtsAlertFormatter.formatPoiAlert(tollBooth, language: AppLanguage.es);
      expect(toll, 'Peaje adelante');
    });
  });
}
