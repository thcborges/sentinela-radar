import 'dart:async';
import '../engine/alert_machine.dart';
import 'tts_alert_formatter.dart';
import 'tts_engine_interface.dart';

/// Gerenciador unificado de áudio automotivo do Sentinela:
/// síntese de voz TTS offline e cálculo de cadência proporcional de bipes de proximidade.
class AudioAlertPlayer {
  final TtsEngineInterface? _ttsEngine;

  int? _lastSpokenPoiId;
  DateTime? _lastSpokenTimestamp;

  AudioAlertPlayer({TtsEngineInterface? ttsEngine}) : _ttsEngine = ttsEngine;

  int? get lastAlertPoiId => _lastSpokenPoiId;

  /// Processa e reproduz áudio adequado para o alerta ativo.
  Future<void> playAlert(
    ActiveAlert alert, {
    required bool isVoiceEnabled,
    required bool isBeepEnabled,
    bool alertOnlyIfOverSpeed = false,
  }) async {
    // 1. Fala via TTS com debounce por POI (não repete o mesmo ponto em menos de 10s)
    if (isVoiceEnabled && _ttsEngine != null) {
      if (alertOnlyIfOverSpeed && !alert.isOverSpeed) {
        return;
      }
      final now = DateTime.now();
      final isNewPoi = _lastSpokenPoiId != alert.poi.id;
      final isDebounceExpired = _lastSpokenTimestamp == null ||
          now.difference(_lastSpokenTimestamp!).inSeconds >= 10;

      if (isNewPoi || isDebounceExpired) {
        _lastSpokenPoiId = alert.poi.id;
        _lastSpokenTimestamp = now;
        final message = TtsAlertFormatter.formatSpokenAlert(alert);
        await _ttsEngine.speak(message);
      }
    }
  }

  /// Calcula o intervalo em milissegundos para bipes de proximidade (Efeito Sonar).
  /// Distância máxima mapeada de 800m (1 bipe/s) a 30m (10 bipes/s = 100ms).
  int calculateBeepIntervalMs(double distanceMeters) {
    if (distanceMeters <= 30.0) return 100;
    if (distanceMeters >= 800.0) return 1000;

    // Interpolação linear entre [30m, 800m] mapeada para [100ms, 1000ms]
    final factor = (distanceMeters - 30.0) / (800.0 - 30.0);
    return (100 + (factor * 900)).round();
  }

  void reset() {
    _lastSpokenPoiId = null;
    _lastSpokenTimestamp = null;
  }

  void dispose() {
    _ttsEngine?.dispose();
  }
}
