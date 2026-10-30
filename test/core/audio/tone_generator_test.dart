import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/audio/tone_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToneGenerator Tests (BDD - Síntese Tonal e Bipes Acústicos)', () {
    test('FakeToneGenerator deve registrar tons reproduzidos e permitir stop', () async {
      final fakeGenerator = FakeToneGenerator();

      expect(fakeGenerator.playedTones, isEmpty);
      expect(fakeGenerator.isPlaying, isFalse);

      final success = await fakeGenerator.playTone(
        frequencyHz: 880.0,
        durationMs: 100,
        volume: 0.8,
      );

      expect(success, isTrue);
      expect(fakeGenerator.playedTones.length, equals(1));
      expect(fakeGenerator.playedTones.first['frequencyHz'], equals(880.0));
      expect(fakeGenerator.playedTones.first['durationMs'], equals(100));
      expect(fakeGenerator.playedTones.first['volume'], equals(0.8));
      expect(fakeGenerator.isPlaying, isTrue);

      await fakeGenerator.stop();
      expect(fakeGenerator.isPlaying, isFalse);
    });

    test('PlatformToneGenerator deve interagir com MethodChannel nativo', () async {
      const channel = MethodChannel('sentinela/tone_generator');
      final log = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'playTone') {
          return true;
        } else if (methodCall.method == 'stop') {
          return null;
        }
        return null;
      });

      final generator = PlatformToneGenerator();
      final result = await generator.playTone(
        frequencyHz: 1200.0,
        durationMs: 80,
      );

      expect(result, isTrue);
      expect(log.length, equals(1));
      expect(log.first.method, equals('playTone'));
      expect(log.first.arguments['frequencyHz'], equals(1200.0));
      expect(log.first.arguments['durationMs'], equals(80));

      await generator.stop();
      expect(log.length, equals(2));
      expect(log.last.method, equals('stop'));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('PlatformToneGenerator deve capturar PlatformException e retornar false', () async {
      const channel = MethodChannel('sentinela/tone_generator');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        throw PlatformException(code: 'ERROR', message: 'Hardware audio unavailable');
      });

      final generator = PlatformToneGenerator();
      final result = await generator.playTone(frequencyHz: 440.0, durationMs: 100);
      expect(result, isFalse);

      // stop não deve lançar exceção
      await generator.stop();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('PlatformToneGenerator deve tratar MissingPluginException e retorno nulo', () async {
      const channel = MethodChannel('sentinela/tone_generator');

      // 1. Simula MissingPluginException
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        throw MissingPluginException('Plugin not registered');
      });

      final generator = PlatformToneGenerator();
      final result = await generator.playTone(frequencyHz: 440.0, durationMs: 100);
      expect(result, isFalse);
      await generator.stop(); // não lança erro

      // 2. Simula retorno nulo
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async => null);

      final nullResult = await generator.playTone(frequencyHz: 440.0, durationMs: 100);
      expect(nullResult, isFalse);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });
}
