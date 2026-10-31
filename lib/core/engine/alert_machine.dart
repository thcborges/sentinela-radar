import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'alert_preferences.dart';
import '../geo/bearing.dart';
import '../geo/haversine.dart';
import '../models/alert_distance_calculator.dart';
import '../models/poi_model.dart';
import '../models/vehicle_profile.dart';

/// Ciclo de estados reativos do motor de alerta.
enum AlertStatus {
  /// Nenhum ponto relevante ou veículo fora do raio de aproximação
  idle,

  /// POI detectado no cone frontal dentro da margem de aproximação
  approaching,

  /// Alerta ativo e velocidade compatível com a via
  alerting,

  /// Alerta crítico: excesso de velocidade ao aproximar-se do ponto fiscalizado
  overSpeed,

  /// Cruzamento do ponto concluído com sucesso
  passed,
}

/// Alerta ativo calculado para um POI específico em relação à posição do veículo.
class ActiveAlert extends Equatable {
  final PoiPoint poi;
  final double distanceMeters;
  final double currentSpeedKmh;
  final AlertStatus status;
  final bool isOverSpeed;
  final double targetBearing;
  final double relativeBearing;

  const ActiveAlert({
    required this.poi,
    required this.distanceMeters,
    required this.currentSpeedKmh,
    required this.status,
    required this.isOverSpeed,
    required this.targetBearing,
    required this.relativeBearing,
  });

  @override
  List<Object?> get props => [
        poi,
        distanceMeters,
        currentSpeedKmh,
        status,
        isOverSpeed,
        targetBearing,
        relativeBearing,
      ];
}

/// Estado imutável emitido pelo [AlertMachine].
class AlertState extends Equatable {
  final AlertStatus status;
  final ActiveAlert? activeAlert;
  final List<ActiveAlert> nearbyAlerts;
  final VehiclePosition? currentPosition;

  const AlertState({
    required this.status,
    this.activeAlert,
    this.nearbyAlerts = const [],
    this.currentPosition,
  });

  factory AlertState.idle() => const AlertState(status: AlertStatus.idle);

  @override
  List<Object?> get props => [
        status,
        activeAlert,
        nearbyAlerts,
        currentPosition,
      ];
}

/// Máquina de estados finitos reativa para processamento contínuo de coordenadas GPS,
/// filtragem geométrica e priorização de alertas de radares, semáforos e pedágios.
class AlertMachine extends Cubit<AlertState> {
  AlertPreferences preferences;
  VehicleProfile vehicleProfile;

  AlertMachine({
    AlertPreferences? preferences,
    VehicleProfile? vehicleProfile,
  })  : preferences = preferences ?? const AlertPreferences(),
        vehicleProfile = vehicleProfile ?? VehicleProfile.car(),
        super(AlertState.idle());

  /// Atualiza as preferências e tolerâncias do motor de alertas.
  void updatePreferences(AlertPreferences newPreferences) {
    preferences = newPreferences;
  }

  /// Atualiza o perfil veicular (CTB) ativo no motor de alertas.
  void updateVehicleProfile(VehicleProfile newProfile) {
    vehicleProfile = newProfile;
  }

  /// Força o retorno imediato ao estado IDLE.
  void reset() {
    emit(AlertState.idle());
  }

  /// Processa a posição atual do veículo [position] confrontando-a com os [candidatePois].
  void updatePosition(
    VehiclePosition position,
    List<PoiPoint> candidatePois, {
    bool isDeadReckoning = false,
  }) {
    // 1. Descarte de sinais de baixa precisão (incerteza > 35m, exceto em Dead Reckoning inercial)
    if (!position.isAccurate && !isDeadReckoning) {
      return;
    }

    final previousActive = state.activeAlert;
    final wasAlerting = state.status == AlertStatus.alerting ||
        state.status == AlertStatus.overSpeed;

    final List<ActiveAlert> detectedAlerts = [];

    // 2. Avalia cada candidato contra os filtros geométricos e dinâmicos
    for (final poi in candidatePois) {
      final distance = haversineDistance(
        position.latitude,
        position.longitude,
        poi.latitude,
        poi.longitude,
      );

      final effectiveSpeedLimit = poi.speedLimit != null
          ? vehicleProfile.resolveSpeedLimit(poi.speedLimit!)
          : null;

      final alertDistance = AlertDistanceCalculator.calculateAlertDistance(
        poi.type,
        position.speedKmh,
        customAnticipationSeconds: preferences.anticipationTimeSeconds * vehicleProfile.lookaheadMultiplier,
      ) * vehicleProfile.lookaheadMultiplier;

      final approachingDistance =
          AlertDistanceCalculator.calculateApproachingDistance(
        poi.type,
        position.speedKmh,
        customAnticipationSeconds: preferences.anticipationTimeSeconds * vehicleProfile.lookaheadMultiplier,
      ) * vehicleProfile.lookaheadMultiplier;

      // Descarte preliminar por distância
      if (distance > approachingDistance) {
        continue;
      }

      // Filtro 1: O ponto deve estar situado no cone frontal do veículo
      final ahead = isPointAhead(
        position.latitude,
        position.longitude,
        position.bearing,
        poi.latitude,
        poi.longitude,
        aheadToleranceDegrees: 40.0,
      );

      if (!ahead) {
        continue;
      }

      // Filtro 2: O rumo do veículo deve coincidir com o sentido cadastrado do POI
      final directionMatch = isDirectionMatching(
        position.bearing,
        poi.direction,
        toleranceDegrees: poi.toleranceAngle,
      );

      if (!directionMatch) {
        continue;
      }

      // Cálculo de azimutes para sonar e HUD
      final targetBearing = initialBearing(
        position.latitude,
        position.longitude,
        poi.latitude,
        poi.longitude,
      );
      final relBearing = bearingDifference(position.bearing, targetBearing);

      // Classificação do estado individual com tolerância customizada e perfil CTB
      final bool isOverSpeed = preferences.isOverSpeed(
        position.speedKmh,
        effectiveSpeedLimit,
      );

      final AlertStatus poiStatus;
      if (distance <= alertDistance) {
        poiStatus =
            isOverSpeed ? AlertStatus.overSpeed : AlertStatus.alerting;
      } else {
        poiStatus = AlertStatus.approaching;
      }

      final effectivePoi = effectiveSpeedLimit != poi.speedLimit
          ? poi.copyWith(speedLimit: effectiveSpeedLimit)
          : poi;

      detectedAlerts.add(ActiveAlert(
        poi: effectivePoi,
        distanceMeters: distance,
        currentSpeedKmh: position.speedKmh,
        status: poiStatus,
        isOverSpeed: isOverSpeed,
        targetBearing: targetBearing,
        relativeBearing: relBearing,
      ));
    }

    // 3. Se há alertas válidos à frente, prioriza o mais crítico
    if (detectedAlerts.isNotEmpty) {
      detectedAlerts.sort((a, b) {
        // OVER_SPEED sempre tem prioridade máxima
        if (a.status == AlertStatus.overSpeed &&
            b.status != AlertStatus.overSpeed) {
          return -1;
        }
        if (b.status == AlertStatus.overSpeed &&
            a.status != AlertStatus.overSpeed) {
          return 1;
        }

        // ALERTING tem prioridade sobre APPROACHING
        if (a.status == AlertStatus.alerting &&
            b.status == AlertStatus.approaching) {
          return -1;
        }
        if (b.status == AlertStatus.alerting &&
            a.status == AlertStatus.approaching) {
          return 1;
        }

        // Se mesmo nível de criticidade, o mais próximo ganha
        return a.distanceMeters.compareTo(b.distanceMeters);
      });

      final bestAlert = detectedAlerts.first;

      emit(AlertState(
        status: bestAlert.status,
        activeAlert: bestAlert,
        nearbyAlerts: detectedAlerts,
        currentPosition: position,
      ));
      return;
    }

    // 4. Detecção de passagem (PASSED)
    // Se estávamos alertando um POI anteriormente e agora ele não está à frente
    if (wasAlerting && previousActive != null) {
      final pointStillAhead = isPointAhead(
        position.latitude,
        position.longitude,
        position.bearing,
        previousActive.poi.latitude,
        previousActive.poi.longitude,
        aheadToleranceDegrees: 90.0,
      );

      final distanceNow = haversineDistance(
        position.latitude,
        position.longitude,
        previousActive.poi.latitude,
        previousActive.poi.longitude,
      );

      // Se o ponto ficou para trás e ainda está relativamente próximo (histerese de 150m)
      if (!pointStillAhead && distanceNow < 150.0) {
        emit(AlertState(
          status: AlertStatus.passed,
          activeAlert: ActiveAlert(
            poi: previousActive.poi,
            distanceMeters: distanceNow,
            currentSpeedKmh: position.speedKmh,
            status: AlertStatus.passed,
            isOverSpeed: false,
            targetBearing: previousActive.targetBearing,
            relativeBearing: 180.0,
          ),
          nearbyAlerts: const [],
          currentPosition: position,
        ));
        return;
      }
    }

    // 5. Nenhum alerta à frente nem passagem recente -> IDLE
    emit(AlertState(
      status: AlertStatus.idle,
      currentPosition: position,
    ));
  }
}
