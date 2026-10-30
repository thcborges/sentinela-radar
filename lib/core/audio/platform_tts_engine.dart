import 'package:flutter_tts/flutter_tts.dart';
import 'tts_engine_interface.dart';

/// Implementação do [TtsEngineInterface] utilizando o plugin nativo `flutter_tts`
/// configurado com síntese offline em português do Brasil (pt-BR).
class PlatformTtsEngine implements TtsEngineInterface {
  final FlutterTts _tts;
  bool _isConfigured = false;

  PlatformTtsEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  Future<void> _ensureConfigured() async {
    if (_isConfigured) return;
    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _isConfigured = true;
    } catch (_) {
      // Falha ao configurar motor TTS em ambientes de teste/headless
    }
  }

  @override
  Future<bool> speak(String text) async {
    try {
      await _ensureConfigured();
      final result = await _tts.speak(text);
      return result == 1 || result == '1';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Ignora erro em ambientes headless
    }
  }

  @override
  void dispose() {
    stop();
  }
}
