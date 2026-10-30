import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/audio/platform_tts_engine.dart';

class MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformTtsEngine Tests (BDD)', () {
    late MockFlutterTts mockTts;
    late PlatformTtsEngine ttsEngine;

    setUp(() {
      mockTts = MockFlutterTts();
      ttsEngine = PlatformTtsEngine(tts: mockTts);
    });

    test('deve configurar idioma pt-BR e falar texto com sucesso', () async {
      when(() => mockTts.setLanguage('pt-BR')).thenAnswer((_) async => 1);
      when(() => mockTts.setSpeechRate(any())).thenAnswer((_) async => 1);
      when(() => mockTts.setVolume(any())).thenAnswer((_) async => 1);
      when(() => mockTts.setPitch(any())).thenAnswer((_) async => 1);
      when(() => mockTts.speak(any())).thenAnswer((_) async => 1);

      final success = await ttsEngine.speak('Radar fixo a 400 metros. Limite 60 km/h');
      expect(success, isTrue);

      verify(() => mockTts.setLanguage('pt-BR')).called(1);
      verify(() => mockTts.speak('Radar fixo a 400 metros. Limite 60 km/h')).called(1);
    });

    test('deve tratar exceção de plataforma no speak retornando false', () async {
      when(() => mockTts.setLanguage('pt-BR')).thenAnswer((_) async => 1);
      when(() => mockTts.setSpeechRate(any())).thenAnswer((_) async => 1);
      when(() => mockTts.setVolume(any())).thenAnswer((_) async => 1);
      when(() => mockTts.setPitch(any())).thenAnswer((_) async => 1);
      when(() => mockTts.speak(any())).thenThrow(Exception('Engine not initialized'));

      final success = await ttsEngine.speak('Teste');
      expect(success, isFalse);
    });

    test('stop deve interromper áudio sem lançar erro', () async {
      when(() => mockTts.stop()).thenAnswer((_) async => 1);

      await ttsEngine.stop();
      verify(() => mockTts.stop()).called(1);
    });

    test('stop com exceção não deve propagar erro', () async {
      when(() => mockTts.stop()).thenThrow(Exception('Headless'));

      await ttsEngine.stop();
    });

    test('dispose deve interromper reprodução', () {
      when(() => mockTts.stop()).thenAnswer((_) async => 1);

      ttsEngine.dispose();
      verify(() => mockTts.stop()).called(1);
    });

    test('construtor padrão sem mock deve instanciar com sucesso', () {
      final engine = PlatformTtsEngine();
      expect(engine, isNotNull);
    });
  });
}
