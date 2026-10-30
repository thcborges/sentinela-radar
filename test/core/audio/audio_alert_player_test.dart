import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/audio/audio_alert_player.dart';
import 'package:sentinela/core/audio/tts_engine_interface.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';

class MockTtsEngine extends Mock implements TtsEngineInterface {}

void main() {
  late MockTtsEngine mockTts;
  late AudioAlertPlayer player;

  setUp(() {
    mockTts = MockTtsEngine();
    when(() => mockTts.speak(any())).thenAnswer((_) async => true);
    player = AudioAlertPlayer(ttsEngine: mockTts);
  });

  tearDown(() {
    player.dispose();
  });

  group('AudioAlertPlayer (Gerenciador de Voz e Bipes Sonar)', () {
    test('deve anunciar alerta via TTS quando novo alerta ativo chegar e voz estiver habilitada', () async {
      const poi = PoiPoint(
        id: 10,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.fixedRadar,
        speedLimit: 60,
      );

      const alert = ActiveAlert(
        poi: poi,
        distanceMeters: 300,
        currentSpeedKmh: 50,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      await player.playAlert(alert, isVoiceEnabled: true, isBeepEnabled: false);

      verify(() => mockTts.speak('Radar fixo, 60 km/h à frente')).called(1);
      expect(player.lastAlertPoiId, equals(10));
    });

    test('não deve repetir anúncio falado contínuo para o mesmo POI antes do intervalo mínimo', () async {
      const poi = PoiPoint(
        id: 10,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.fixedRadar,
        speedLimit: 60,
      );

      const alert = ActiveAlert(
        poi: poi,
        distanceMeters: 300,
        currentSpeedKmh: 50,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      await player.playAlert(alert, isVoiceEnabled: true, isBeepEnabled: false);
      // Segunda chamada imediata para o mesmo POI
      await player.playAlert(alert, isVoiceEnabled: true, isBeepEnabled: false);

      verify(() => mockTts.speak(any())).called(1); // apenas 1 vez
    });

    test('deve calcular intervalo de bipe do sonar inversamente proporcional à distância', () {
      expect(player.calculateBeepIntervalMs(800), equals(1000)); // Longe: cadência lenta (1 bipe/segundo)
      expect(player.calculateBeepIntervalMs(415), equals(550));  // Meio do intervalo [30, 800]: (385/770 * 900) + 100 = 550
      expect(player.calculateBeepIntervalMs(30), equals(100));   // Imediato: cadência máxima (100ms)
      expect(player.calculateBeepIntervalMs(10), equals(100));   // Abaixo do mínimo: trava em 100ms
      expect(player.calculateBeepIntervalMs(1000), equals(1000)); // Acima do máximo: trava em 1000ms
    });

    test('não deve falar se isVoiceEnabled for falso ou ttsEngine for nulo', () async {
      const alert = ActiveAlert(
        poi: PoiPoint(id: 20, latitude: 0, longitude: 0, type: PoiType.fixedRadar),
        distanceMeters: 200,
        currentSpeedKmh: 50,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      // Voice disabled
      await player.playAlert(alert, isVoiceEnabled: false, isBeepEnabled: true);
      verifyNever(() => mockTts.speak(any()));

      // Engine nulo
      final nullEnginePlayer = AudioAlertPlayer(ttsEngine: null);
      await nullEnginePlayer.playAlert(alert, isVoiceEnabled: true, isBeepEnabled: true);
      expect(nullEnginePlayer.lastAlertPoiId, isNull);

      // Reset
      await player.playAlert(alert, isVoiceEnabled: true, isBeepEnabled: true);
      expect(player.lastAlertPoiId, equals(20));
      player.reset();
      expect(player.lastAlertPoiId, isNull);
    });
  });
}
