import 'package:equatable/equatable.dart';

/// Preferências e tolerâncias customizáveis para parametrização do motor de alertas do Sentinela.
class AlertPreferences extends Equatable {
  final double speedTolerancePercent;
  final double speedToleranceKmh;
  final bool alertOnlyIfOverSpeed;
  final double anticipationTimeSeconds;
  final bool soundEnabled;
  final bool voiceEnabled;

  const AlertPreferences({
    this.speedTolerancePercent = 0.0,
    this.speedToleranceKmh = 0.0,
    this.alertOnlyIfOverSpeed = false,
    this.anticipationTimeSeconds = 15.0,
    this.soundEnabled = true,
    this.voiceEnabled = true,
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
    };
  }

  factory AlertPreferences.fromJson(Map<String, dynamic> json) {
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
      ];
}
