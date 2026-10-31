import 'package:flutter/services.dart';

/// Contrato para geração e emissão de tons sonoros e bipes acústicos sintetizados.
abstract class ToneGeneratorInterface {
  Future<bool> playTone({
    required double frequencyHz,
    required int durationMs,
    double volume = 1.0,
  });

  Future<void> stop();
}

/// Implementação em memória para testes herméticos em Linux / CI.
class FakeToneGenerator implements ToneGeneratorInterface {
  final List<Map<String, dynamic>> playedTones = [];
  bool isPlaying = false;

  @override
  Future<bool> playTone({
    required double frequencyHz,
    required int durationMs,
    double volume = 1.0,
  }) async {
    playedTones.add({
      'frequencyHz': frequencyHz,
      'durationMs': durationMs,
      'volume': volume,
    });
    isPlaying = true;
    return true;
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
  }
}

/// Adaptador concreto via MethodChannel para geração nativa de tons de áudio (Android AudioTrack / iOS AVAudioPlayer).
class PlatformToneGenerator implements ToneGeneratorInterface {
  static const MethodChannel _channel = MethodChannel('sentinela/tone_generator');

  @override
  Future<bool> playTone({
    required double frequencyHz,
    required int durationMs,
    double volume = 1.0,
  }) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('playTone', {
        'frequencyHz': frequencyHz,
        'durationMs': durationMs,
        'volume': volume,
      });
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on PlatformException catch (_) {
      // Ignora falhas ao parar áudio
    } on MissingPluginException catch (_) {
      // Ignora ausência de plugin
    }
  }
}
