import 'dart:async';
import 'package:sentinela/core/audio/tone_generator.dart';
import '../engines/alert_machine.dart';
import 'tts_alert_formatter.dart';
import 'tts_engine_interface.dart';

/// Gerenciador unificado de áudio automotivo do Sentinela:
/// síntese de voz TTS offline e cálculo de cadência proporcional de bipes de proximidade.
class AudioAlertPlayer {
  final TtsEngineInterface? _ttsEngine;
  final ToneGeneratorInterface? _toneGenerator;

  int? _lastSpokenPoiId;
  DateTime? _lastSpokenTimestamp;
  bool _lastSpokenWasOverSpeed = false;
  DateTime? _lastBeepTimestamp;

  AudioAlertPlayer({
    TtsEngineInterface? ttsEngine,
    ToneGeneratorInterface? toneGenerator,
  })  : _ttsEngine = ttsEngine,
        _toneGenerator = toneGenerator;

  int? get lastAlertPoiId => _lastSpokenPoiId;
  ToneGeneratorInterface? get toneGenerator => _toneGenerator;
  TtsEngineInterface? get ttsEngine => _ttsEngine;

  /// Processa e reproduz áudio adequado para o alerta ativo.
  Future<void> playAlert(
    ActiveAlert alert, {
    required bool isVoiceEnabled,
    required bool isBeepEnabled,
    bool alertOnlyIfOverSpeed = false,
  }) async {
    if (alertOnlyIfOverSpeed && !alert.isOverSpeed) {
      return;
    }

    final now = DateTime.now();

    // 1. Fala via TTS com debounce por POI e preempção/escalação em sobrevelocidade
    if (isVoiceEnabled && _ttsEngine != null) {
      final isNewPoi = _lastSpokenPoiId != alert.poi.id;
      final isDebounceExpired = _lastSpokenTimestamp == null ||
          now.difference(_lastSpokenTimestamp!).inSeconds >= 10;
      final isEscalatingToOverSpeed =
          alert.isOverSpeed && !_lastSpokenWasOverSpeed;

      if (isNewPoi || isEscalatingToOverSpeed || isDebounceExpired) {
        _lastSpokenPoiId = alert.poi.id;
        _lastSpokenTimestamp = now;
        _lastSpokenWasOverSpeed = alert.isOverSpeed;
        final message = TtsAlertFormatter.formatSpokenAlert(alert);
        // Interrompe fala anterior ativa antes de sintetizar novo alerta urgente
        try {
          await _ttsEngine.stop();
        } catch (_) {}
        await _ttsEngine.speak(message);
      }
    }

    // 2. Emite bipe tonal proporcional à proximidade (efeito Sonar)
    if (isBeepEnabled && _toneGenerator != null) {
      final intervalMs = calculateBeepIntervalMs(alert.distanceMeters);
      final isBeepDue = _lastBeepTimestamp == null ||
          now.difference(_lastBeepTimestamp!).inMilliseconds >= intervalMs;

      if (isBeepDue) {
        _lastBeepTimestamp = now;
        final frequency = alert.isOverSpeed ? 1200.0 : 880.0;
        final duration = alert.isOverSpeed ? 120 : 80;
        await _toneGenerator.playTone(
          frequencyHz: frequency,
          durationMs: duration,
        );
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
    _lastSpokenWasOverSpeed = false;
    _lastBeepTimestamp = null;
    try {
      _ttsEngine?.stop();
    } catch (_) {}
    _toneGenerator?.stop();
  }

  void dispose() {
    _toneGenerator?.stop();
    _ttsEngine?.dispose();
  }
}
