import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/audio/audio_alert_player.dart';
import 'package:sentinela/core/audio/tone_generator.dart';
import 'package:sentinela/core/audio/tts_engine_interface.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';

class MockTtsEngine extends Mock implements TtsEngineInterface {}

void main() {
  late MockTtsEngine mockTts;
  late FakeToneGenerator fakeTone;
  late AudioAlertPlayer player;

  setUp(() {
    mockTts = MockTtsEngine();
    fakeTone = FakeToneGenerator();
    when(() => mockTts.speak(any())).thenAnswer((_) async => true);
    when(() => mockTts.stop()).thenAnswer((_) async => true);
    player = AudioAlertPlayer(ttsEngine: mockTts, toneGenerator: fakeTone);
  });

  tearDown(() {
    player.dispose();
  });

  group('AudioAlertPlayer (Gerenciador de Voz e Bipes Sonar)', () {
    test('deve expor os motores tts e tone generator corretamente', () {
      expect(player.ttsEngine, equals(mockTts));
      expect(player.toneGenerator, equals(fakeTone));
    });

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

    test('não deve falar se alertOnlyIfOverSpeed for verdadeiro e isOverSpeed for falso', () async {
      const normalAlert = ActiveAlert(
        poi: PoiPoint(id: 30, latitude: 0, longitude: 0, type: PoiType.fixedRadar, speedLimit: 60),
        distanceMeters: 200,
        currentSpeedKmh: 55,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      await player.playAlert(
        normalAlert,
        isVoiceEnabled: true,
        isBeepEnabled: false,
        alertOnlyIfOverSpeed: true,
      );

      verifyNever(() => mockTts.speak(any()));

      const overSpeedAlert = ActiveAlert(
        poi: PoiPoint(id: 31, latitude: 0, longitude: 0, type: PoiType.fixedRadar, speedLimit: 60),
        distanceMeters: 200,
        currentSpeedKmh: 75,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 0,
        relativeBearing: 0,
      );

      await player.playAlert(
        overSpeedAlert,
        isVoiceEnabled: true,
        isBeepEnabled: false,
        alertOnlyIfOverSpeed: true,
      );

      verify(() => mockTts.speak(any())).called(1);
    });

    test('deve emitir bipes com frequencia 880Hz em alerta normal e 1200Hz em excesso de velocidade', () async {
      const normalAlert = ActiveAlert(
        poi: PoiPoint(id: 40, latitude: 0, longitude: 0, type: PoiType.fixedRadar, speedLimit: 60),
        distanceMeters: 500,
        currentSpeedKmh: 55,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      await player.playAlert(normalAlert, isVoiceEnabled: false, isBeepEnabled: true);
      expect(fakeTone.playedTones.length, equals(1));
      expect(fakeTone.playedTones.first['frequencyHz'], equals(880.0));
      expect(fakeTone.playedTones.first['durationMs'], equals(80));

      // Segundo bipe imediato deve respeitar a cadência calculada (não emite novo bipe imediato)
      await player.playAlert(normalAlert, isVoiceEnabled: false, isBeepEnabled: true);
      expect(fakeTone.playedTones.length, equals(1));

      // Reset limpa o timer e para o tone generator
      player.reset();
      expect(fakeTone.isPlaying, isFalse);

      const overSpeedAlert = ActiveAlert(
        poi: PoiPoint(id: 41, latitude: 0, longitude: 0, type: PoiType.fixedRadar, speedLimit: 60),
        distanceMeters: 100,
        currentSpeedKmh: 80,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 0,
        relativeBearing: 0,
      );

      await player.playAlert(overSpeedAlert, isVoiceEnabled: false, isBeepEnabled: true);
      expect(fakeTone.playedTones.length, equals(2));
      expect(fakeTone.playedTones.last['frequencyHz'], equals(1200.0));
      expect(fakeTone.playedTones.last['durationMs'], equals(120));
    });

    test('BUG #35 REGRESSÃO: deve chamar stop() no TTS engine antes de despachar novo alerta via TTS', () async {
      const alert = ActiveAlert(
        poi: PoiPoint(id: 50, latitude: 0, longitude: 0, type: PoiType.fixedRadar, speedLimit: 60),
        distanceMeters: 300,
        currentSpeedKmh: 50,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      await player.playAlert(alert, isVoiceEnabled: true, isBeepEnabled: false);

      verifyInOrder([
        () => mockTts.stop(),
        () => mockTts.speak('Radar fixo, 60 km/h à frente'),
      ]);
    });

    test('BUG #35 REGRESSÃO: deve interromper fala anterior e disparar aviso urgente quando condutor acelerar para overSpeed no mesmo POI antes do debounce de 10s', () async {
      const normalAlert = ActiveAlert(
        poi: PoiPoint(id: 60, latitude: 0, longitude: 0, type: PoiType.fixedRadar, speedLimit: 60),
        distanceMeters: 350,
        currentSpeedKmh: 50,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      // 1. Alerta normal de aproximação
      await player.playAlert(normalAlert, isVoiceEnabled: true, isBeepEnabled: false);
      verify(() => mockTts.speak('Radar fixo, 60 km/h à frente')).called(1);

      // 2. Condutor acelera 1 segundo depois no mesmo POI (isOverSpeed = true)
      const overSpeedAlert = ActiveAlert(
        poi: PoiPoint(id: 60, latitude: 0, longitude: 0, type: PoiType.fixedRadar, speedLimit: 60),
        distanceMeters: 280,
        currentSpeedKmh: 75,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 0,
        relativeBearing: 0,
      );

      await player.playAlert(overSpeedAlert, isVoiceEnabled: true, isBeepEnabled: false);

      // Deve ter interrompido a fala anterior e falado o aviso urgente de redução
      verify(() => mockTts.speak('Atenção: Reduza a velocidade. Radar fixo, 60 km/h à frente')).called(1);
    });

    test('deve chamar stop() no motor TTS e no tone generator ao resetar o player', () async {
      player.reset();
      verify(() => mockTts.stop()).called(1);
      expect(fakeTone.isPlaying, isFalse);
    });
  });
}
