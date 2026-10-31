import 'package:flutter/services.dart';
import '../../domain/engines/alert_machine.dart';
import '../../domain/models/poi_model.dart';

/// Padrões de pulsação e vibração háptica para alertas veiculares e acessibilidade tátil.
enum HapticPattern {
  /// Clique curto para toques e interações da interface do usuário.
  click,

  /// Pulso único sutil para avisos leves (lombadas físicas, pedágios).
  gentleNotice,

  /// Pulso duplo pronunciado para aproximação de radar dentro do limite da via.
  radarWarning,

  /// Pulsação crítica e incisiva para excesso de velocidade ao aproximar-se do radar.
  criticalOverSpeed,

  /// Pulso de confirmação de passagem ou marcação de POI.
  successConfirmation,
}

/// Níveis de intensidade de feedback háptico configuráveis pelo condutor.
enum HapticIntensity {
  off,
  light,
  medium,
  strong;

  String get displayName {
    switch (this) {
      case HapticIntensity.off:
        return 'Desativado';
      case HapticIntensity.light:
        return 'Suave';
      case HapticIntensity.medium:
        return 'Médio';
      case HapticIntensity.strong:
        return 'Forte';
    }
  }
}

/// Abstração para acionamento das chamadas de plataforma do Flutter HapticFeedback.
abstract class HapticPlatformBridge {
  Future<void> selectionClick();
  Future<void> lightImpact();
  Future<void> mediumImpact();
  Future<void> heavyImpact();
  Future<void> vibrate();
}

/// Implementação padrão que invoca diretamente o subsistema nativo do Flutter com blindagem defensiva.
class DefaultHapticPlatformBridge implements HapticPlatformBridge {
  const DefaultHapticPlatformBridge();

  @override
  Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  @override
  Future<void> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  @override
  Future<void> mediumImpact() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  @override
  Future<void> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  @override
  Future<void> vibrate() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}

/// Motor de feedback háptico veicular com controle de cadência, intensidade e debounce de segurança.
class HapticFeedbackEngine {
  final HapticPlatformBridge _bridge;

  int? _lastAlertPoiId;
  DateTime? _lastOverSpeedVibration;
  final Duration _overSpeedDebounceInterval;

  HapticFeedbackEngine({
    HapticPlatformBridge? bridge,
    Duration overSpeedDebounceInterval = const Duration(milliseconds: 1400),
  })  : _bridge = bridge ?? const DefaultHapticPlatformBridge(),
        _overSpeedDebounceInterval = overSpeedDebounceInterval;

  /// Reseta registros de debounce para novos ciclos de teste ou trajetos.
  void resetDebounce() {
    _lastAlertPoiId = null;
    _lastOverSpeedVibration = null;
  }

  /// Dispara um padrão tátil considerando a intensidade configurada.
  Future<void> trigger(
    HapticPattern pattern, {
    HapticIntensity intensity = HapticIntensity.medium,
  }) async {
    if (intensity == HapticIntensity.off) return;

    switch (pattern) {
      case HapticPattern.click:
        await _bridge.selectionClick();
        break;

      case HapticPattern.gentleNotice:
        if (intensity == HapticIntensity.light) {
          await _bridge.lightImpact();
        } else if (intensity == HapticIntensity.medium) {
          await _bridge.mediumImpact();
        } else {
          await _bridge.heavyImpact();
        }
        break;

      case HapticPattern.radarWarning:
        if (intensity == HapticIntensity.light) {
          await _bridge.mediumImpact();
        } else if (intensity == HapticIntensity.medium) {
          await _bridge.heavyImpact();
          await _bridge.mediumImpact();
        } else {
          await _bridge.heavyImpact();
          await _bridge.heavyImpact();
        }
        break;

      case HapticPattern.criticalOverSpeed:
        await _bridge.vibrate();
        break;

      case HapticPattern.successConfirmation:
        await _bridge.mediumImpact();
        await _bridge.lightImpact();
        break;
    }
  }

  /// Avalia um [ActiveAlert] em tempo real e emite o padrão háptico correspondente.
  Future<void> triggerForAlert(
    ActiveAlert alert, {
    bool hapticEnabled = true,
    HapticIntensity intensity = HapticIntensity.medium,
  }) async {
    if (!hapticEnabled || intensity == HapticIntensity.off) return;

    final now = DateTime.now();

    // 1. Alerta crítico de excesso de velocidade (pulsação repetida com debounce)
    if (alert.isOverSpeed) {
      final isDebounceExpired = _lastOverSpeedVibration == null ||
          now.difference(_lastOverSpeedVibration!) >= _overSpeedDebounceInterval;

      if (isDebounceExpired) {
        _lastOverSpeedVibration = now;
        await trigger(HapticPattern.criticalOverSpeed, intensity: intensity);
      }
      return;
    }

    // 2. Alerta preventivo com velocidade compatível (dispara na entrada da aproximação por POI)
    if (_lastAlertPoiId != alert.poi.id) {
      _lastAlertPoiId = alert.poi.id;

      if (alert.poi.type == PoiType.physicalSpeedBump ||
          alert.poi.type == PoiType.tollBooth) {
        await trigger(HapticPattern.gentleNotice, intensity: intensity);
      } else {
        await trigger(HapticPattern.radarWarning, intensity: intensity);
      }
    }
  }

  /// Feedback ao ultrapassar com sucesso um POI.
  Future<void> triggerPoiPassed({
    bool hapticEnabled = true,
    HapticIntensity intensity = HapticIntensity.medium,
  }) async {
    if (!hapticEnabled || intensity == HapticIntensity.off) return;
    await trigger(HapticPattern.successConfirmation, intensity: intensity);
  }

  /// Feedback ao reportar rapidamente um POI na tela pelo condutor.
  Future<void> triggerQuickReport({
    bool hapticEnabled = true,
    HapticIntensity intensity = HapticIntensity.medium,
  }) async {
    if (!hapticEnabled || intensity == HapticIntensity.off) return;
    await trigger(HapticPattern.successConfirmation, intensity: intensity);
  }
}
