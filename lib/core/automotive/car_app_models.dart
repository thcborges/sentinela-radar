import 'package:equatable/equatable.dart';
import '../engine/alert_machine.dart';
import '../models/poi_model.dart';

/// Status da conexão com a central multimídia veicular.
enum CarConnectionStatus {
  disconnected,
  connecting,
  connectedAndroidAuto,
  connectedCarPlay;

  bool get isConnected =>
      this == CarConnectionStatus.connectedAndroidAuto ||
      this == CarConnectionStatus.connectedCarPlay;

  String get displayName {
    switch (this) {
      case CarConnectionStatus.connectedAndroidAuto:
        return 'Android Auto';
      case CarConnectionStatus.connectedCarPlay:
        return 'Apple CarPlay';
      case CarConnectionStatus.connecting:
        return 'Conectando...';
      case CarConnectionStatus.disconnected:
        return 'Desconectado';
    }
  }
}

/// Níveis de restrição de atenção ao volante (Driver Distraction Guidelines).
enum CarDistractionLevel {
  parked,
  driving,
  highSpeed;

  int get maxAllowedActions {
    switch (this) {
      case CarDistractionLevel.parked:
        return 6;
      case CarDistractionLevel.driving:
        return 4;
      case CarDistractionLevel.highSpeed:
        return 2;
    }
  }
}

/// Ações rápidas acionadas no volante ou display do painel do carro.
enum CarAction {
  quickReportRadar,
  quickReportSpeedBump,
  toggleMute,
  toggleHudTheme,
  dismissAlert;

  static CarAction fromName(String name) {
    for (final action in CarAction.values) {
      if (action.name == name) return action;
    }
    return CarAction.quickReportRadar;
  }
}

/// Item resumido de radar/lombada à frente para renderização no visor da central.
class CarSonarItem extends Equatable {
  final String label;
  final double distanceMeters;
  final double relativeAngleDeg;
  final PoiType poiType;
  final bool isCritical;

  const CarSonarItem({
    required this.label,
    required this.distanceMeters,
    required this.relativeAngleDeg,
    required this.poiType,
    required this.isCritical,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'distanceMeters': distanceMeters,
      'relativeAngleDeg': relativeAngleDeg,
      'poiType': poiType.name,
      'isCritical': isCritical,
    };
  }

  factory CarSonarItem.fromMap(Map<String, dynamic> map) {
    return CarSonarItem(
      label: map['label'] as String? ?? '',
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      relativeAngleDeg: (map['relativeAngleDeg'] as num?)?.toDouble() ?? 0.0,
      poiType: PoiType.fromName(map['poiType'] as String? ?? 'fixedRadar'),
      isCritical: map['isCritical'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        label,
        distanceMeters,
        relativeAngleDeg,
        poiType,
        isCritical,
      ];
}

/// Pacote imutável de telemetria e alertas transmitido para a central multimídia.
class CarAppData extends Equatable {
  final double currentSpeedKmh;
  final int? speedLimitKmh;
  final String roadName;
  final AlertStatus alertStatus;
  final ActiveAlert? activeAlert;
  final CarConnectionStatus connectionStatus;
  final bool isMuted;
  final bool isNightMode;
  final CarDistractionLevel distractionLevel;
  final List<CarSonarItem> simplifiedSonarItems;
  final List<CarAction> allowedActions;

  const CarAppData({
    this.currentSpeedKmh = 0.0,
    this.speedLimitKmh,
    this.roadName = 'Monitorando vias...',
    this.alertStatus = AlertStatus.idle,
    this.activeAlert,
    this.connectionStatus = CarConnectionStatus.disconnected,
    this.isMuted = false,
    this.isNightMode = true,
    this.distractionLevel = CarDistractionLevel.parked,
    this.simplifiedSonarItems = const [],
    this.allowedActions = const [
      CarAction.quickReportRadar,
      CarAction.toggleMute,
    ],
  });

  bool get isOverSpeed =>
      alertStatus == AlertStatus.overSpeed ||
      (activeAlert != null && activeAlert!.isOverSpeed);

  CarAppData copyWith({
    double? currentSpeedKmh,
    int? speedLimitKmh,
    String? roadName,
    AlertStatus? alertStatus,
    ActiveAlert? activeAlert,
    CarConnectionStatus? connectionStatus,
    bool? isMuted,
    bool? isNightMode,
    CarDistractionLevel? distractionLevel,
    List<CarSonarItem>? simplifiedSonarItems,
    List<CarAction>? allowedActions,
  }) {
    return CarAppData(
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      speedLimitKmh: speedLimitKmh ?? this.speedLimitKmh,
      roadName: roadName ?? this.roadName,
      alertStatus: alertStatus ?? this.alertStatus,
      activeAlert: activeAlert ?? this.activeAlert,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isMuted: isMuted ?? this.isMuted,
      isNightMode: isNightMode ?? this.isNightMode,
      distractionLevel: distractionLevel ?? this.distractionLevel,
      simplifiedSonarItems: simplifiedSonarItems ?? this.simplifiedSonarItems,
      allowedActions: allowedActions ?? this.allowedActions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentSpeedKmh': currentSpeedKmh,
      'speedLimitKmh': speedLimitKmh,
      'roadName': roadName,
      'alertStatus': alertStatus.name,
      'isOverSpeed': isOverSpeed,
      'activeAlertDistance': activeAlert?.distanceMeters,
      'activeAlertPoiType': activeAlert?.poi.type.name,
      'connectionStatus': connectionStatus.name,
      'isMuted': isMuted,
      'isNightMode': isNightMode,
      'distractionLevel': distractionLevel.name,
      'simplifiedSonarItems':
          simplifiedSonarItems.map((item) => item.toMap()).toList(),
      'allowedActions': allowedActions.map((a) => a.name).toList(),
    };
  }

  factory CarAppData.fromMap(Map<String, dynamic> map) {
    final alertStatusName = map['alertStatus'] as String? ?? 'idle';
    final alertStatus = AlertStatus.values.firstWhere(
      (s) => s.name == alertStatusName,
      orElse: () => AlertStatus.idle,
    );

    final connStatusName =
        map['connectionStatus'] as String? ?? 'disconnected';
    final connectionStatus = CarConnectionStatus.values.firstWhere(
      (c) => c.name == connStatusName,
      orElse: () => CarConnectionStatus.disconnected,
    );

    final levelName = map['distractionLevel'] as String? ?? 'parked';
    final distractionLevel = CarDistractionLevel.values.firstWhere(
      (l) => l.name == levelName,
      orElse: () => CarDistractionLevel.parked,
    );

    final rawSonar = map['simplifiedSonarItems'] as List? ?? [];
    final sonarItems = rawSonar
        .whereType<Map<String, dynamic>>()
        .map(CarSonarItem.fromMap)
        .toList();

    final rawActions = map['allowedActions'] as List? ?? [];
    final actions = rawActions
        .whereType<String>()
        .map(CarAction.fromName)
        .toList();

    return CarAppData(
      currentSpeedKmh: (map['currentSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      speedLimitKmh: map['speedLimitKmh'] as int?,
      roadName: map['roadName'] as String? ?? 'Monitorando vias...',
      alertStatus: alertStatus,
      connectionStatus: connectionStatus,
      isMuted: map['isMuted'] as bool? ?? false,
      isNightMode: map['isNightMode'] as bool? ?? true,
      distractionLevel: distractionLevel,
      simplifiedSonarItems: sonarItems,
      allowedActions: actions.isEmpty
          ? const [CarAction.quickReportRadar, CarAction.toggleMute]
          : actions,
    );
  }

  @override
  List<Object?> get props => [
        currentSpeedKmh,
        speedLimitKmh,
        roadName,
        alertStatus,
        activeAlert,
        connectionStatus,
        isMuted,
        isNightMode,
        distractionLevel,
        simplifiedSonarItems,
        allowedActions,
      ];
}
