import 'package:equatable/equatable.dart';
import '../l10n/app_language.dart';
import '../platform/haptic_feedback_engine.dart';

/// Preferências e tolerâncias customizáveis para parametrização do motor de alertas do Sentinela.
class AlertPreferences extends Equatable {
  final double speedTolerancePercent;
  final double speedToleranceKmh;
  final bool alertOnlyIfOverSpeed;
  final double anticipationTimeSeconds;
  final bool soundEnabled;
  final bool voiceEnabled;
  final bool hapticEnabled;
  final HapticIntensity hapticIntensity;
  final AppLanguage language;
  final bool highContrastMode;

  const AlertPreferences({
    this.speedTolerancePercent = 0.0,
    this.speedToleranceKmh = 0.0,
    this.alertOnlyIfOverSpeed = false,
    this.anticipationTimeSeconds = 15.0,
    this.soundEnabled = true,
    this.voiceEnabled = true,
    this.hapticEnabled = true,
    this.hapticIntensity = HapticIntensity.medium,
    this.language = AppLanguage.pt,
    this.highContrastMode = false,
  });

  /// Determina se [currentSpeedKmh] excede o [speedLimit] considerando tolerâncias absolutas e percentuais.
  bool isOverSpeed(double currentSpeedKmh, int? speedLimit) {
    if (speedLimit == null) return false;
    final maxAllowed = speedLimit +
        speedToleranceKmh +
        (speedLimit * speedTolerancePercent);
    return currentSpeedKmh > maxAllowed;
  }

  AlertPreferences copyWith({
    double? speedTolerancePercent,
    double? speedToleranceKmh,
    bool? alertOnlyIfOverSpeed,
    double? anticipationTimeSeconds,
    bool? soundEnabled,
    bool? voiceEnabled,
    bool? hapticEnabled,
    HapticIntensity? hapticIntensity,
    AppLanguage? language,
    bool? highContrastMode,
  }) {
    return AlertPreferences(
      speedTolerancePercent:
          speedTolerancePercent ?? this.speedTolerancePercent,
      speedToleranceKmh: speedToleranceKmh ?? this.speedToleranceKmh,
      alertOnlyIfOverSpeed: alertOnlyIfOverSpeed ?? this.alertOnlyIfOverSpeed,
      anticipationTimeSeconds:
          anticipationTimeSeconds ?? this.anticipationTimeSeconds,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      hapticIntensity: hapticIntensity ?? this.hapticIntensity,
      language: language ?? this.language,
      highContrastMode: highContrastMode ?? this.highContrastMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speedTolerancePercent': speedTolerancePercent,
      'speedToleranceKmh': speedToleranceKmh,
      'alertOnlyIfOverSpeed': alertOnlyIfOverSpeed,
      'anticipationTimeSeconds': anticipationTimeSeconds,
      'soundEnabled': soundEnabled,
      'voiceEnabled': voiceEnabled,
      'hapticEnabled': hapticEnabled,
      'hapticIntensity': hapticIntensity.name,
      'language': language.name,
      'highContrastMode': highContrastMode,
    };
  }

  factory AlertPreferences.fromJson(Map<String, dynamic> json) {
    HapticIntensity parseHaptic(dynamic val) {
      if (val is String) {
        for (final item in HapticIntensity.values) {
          if (item.name == val) return item;
        }
      }
      return HapticIntensity.medium;
    }

    AppLanguage parseLang(dynamic val) {
      if (val is String) {
        return AppLanguage.fromCode(val);
      }
      return AppLanguage.pt;
    }

    return AlertPreferences(
      speedTolerancePercent:
          (json['speedTolerancePercent'] as num?)?.toDouble() ?? 0.0,
      speedToleranceKmh:
          (json['speedToleranceKmh'] as num?)?.toDouble() ?? 0.0,
      alertOnlyIfOverSpeed: json['alertOnlyIfOverSpeed'] as bool? ?? false,
      anticipationTimeSeconds:
          (json['anticipationTimeSeconds'] as num?)?.toDouble() ?? 15.0,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      voiceEnabled: json['voiceEnabled'] as bool? ?? true,
      hapticEnabled: json['hapticEnabled'] as bool? ?? true,
      hapticIntensity: parseHaptic(json['hapticIntensity']),
      language: parseLang(json['language']),
      highContrastMode: json['highContrastMode'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        speedTolerancePercent,
        speedToleranceKmh,
        alertOnlyIfOverSpeed,
        anticipationTimeSeconds,
        soundEnabled,
        voiceEnabled,
        hapticEnabled,
        hapticIntensity,
        language,
        highContrastMode,
      ];
}
