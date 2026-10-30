import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import '../geo/bearing.dart';
import '../geo/haversine.dart';
import '../models/poi_model.dart';

/// Definição de um trecho rodoviário monitorado por velocidade média (Radar de Trecho).
class AverageSpeedCorridor extends Equatable {
  final String id;
  final String name;
  final PoiPoint startPoi;
  final PoiPoint endPoi;
  final double lengthMeters;
  final double speedLimitKmh;

  const AverageSpeedCorridor({
    required this.id,
    required this.name,
    required this.startPoi,
    required this.endPoi,
    required this.lengthMeters,
    required this.speedLimitKmh,
  });

  /// Construtor de conveniência a partir de coordenadas geográficas diretas.
  factory AverageSpeedCorridor.fromCoordinates({
    required String id,
    required String name,
    required double speedLimitKmh,
    required double entryLatitude,
    required double entryLongitude,
    double? entryBearing,
    required double exitLatitude,
    required double exitLongitude,
    double? exitBearing,
    double? lengthMeters,
  }) {
    final startPoi = PoiPoint(
      id: id.hashCode,
      latitude: entryLatitude,
      longitude: entryLongitude,
      type: PoiType.fixedRadar,
      speedLimit: speedLimitKmh.round(),
      roadName: name,
      direction: entryBearing?.round(),
    );

    final endPoi = PoiPoint(
      id: (id.hashCode + 1),
      latitude: exitLatitude,
      longitude: exitLongitude,
      type: PoiType.fixedRadar,
      speedLimit: speedLimitKmh.round(),
      roadName: name,
      direction: exitBearing?.round(),
    );

    final computedLength = lengthMeters ??
        haversineDistance(entryLatitude, entryLongitude, exitLatitude, exitLongitude);

    return AverageSpeedCorridor(
      id: id,
      name: name,
      startPoi: startPoi,
      endPoi: endPoi,
      lengthMeters: computedLength,
      speedLimitKmh: speedLimitKmh,
    );
  }

  @override
  List<Object?> get props => [id, name, startPoi, endPoi, lengthMeters, speedLimitKmh];
}

/// Resultado emitido ao concluir a travessia de um trecho fiscalizado.
class SectionControlResult extends Equatable {
  final String corridorId;
  final bool isCompleted;
  final double averageSpeedKmh;
  final bool isOverSpeed;
  final int elapsedSeconds;
  final double distanceMeters;

  const SectionControlResult({
    required this.corridorId,
    required this.isCompleted,
    required this.averageSpeedKmh,
    required this.isOverSpeed,
    required this.elapsedSeconds,
    required this.distanceMeters,
  });

  @override
  List<Object?> get props => [
        corridorId,
        isCompleted,
        averageSpeedKmh,
        isOverSpeed,
        elapsedSeconds,
        distanceMeters,
      ];
}

/// Estado reativo instantâneo do monitoramento de velocidade média.
class SectionControlState extends Equatable {
  final bool isActive;
  final AverageSpeedCorridor? corridor;
  final DateTime? startTime;
  final VehiclePosition? lastPosition;
  final double distanceCoveredMeters;
  final int elapsedSeconds;
  final double averageSpeedKmh;
  final bool isOverAverageSpeed;
  final double remainingMeters;
  final int targetRemainingSeconds;

  const SectionControlState({
    this.isActive = false,
    this.corridor,
    this.startTime,
    this.lastPosition,
    double distanceCoveredMeters = 0.0,
    double? coveredDistanceMeters,
    this.elapsedSeconds = 0,
    this.averageSpeedKmh = 0.0,
    bool isOverAverageSpeed = false,
    bool? isOverSpeed,
    double remainingMeters = 0.0,
    double? remainingDistanceMeters,
    this.targetRemainingSeconds = 0,
  })  : distanceCoveredMeters = coveredDistanceMeters ?? distanceCoveredMeters,
        isOverAverageSpeed = isOverSpeed ?? isOverAverageSpeed,
        remainingMeters = remainingDistanceMeters ?? remainingMeters;

  bool get isOverSpeed => isOverAverageSpeed;
  double get remainingDistanceMeters => remainingMeters;
  double get coveredDistanceMeters => distanceCoveredMeters;

  SectionControlState copyWith({
    bool? isActive,
    AverageSpeedCorridor? corridor,
    DateTime? startTime,
    VehiclePosition? lastPosition,
    double? distanceCoveredMeters,
    int? elapsedSeconds,
    double? averageSpeedKmh,
    bool? isOverAverageSpeed,
    double? remainingMeters,
    int? targetRemainingSeconds,
  }) {
    return SectionControlState(
      isActive: isActive ?? this.isActive,
      corridor: corridor ?? this.corridor,
      startTime: startTime ?? this.startTime,
      lastPosition: lastPosition ?? this.lastPosition,
      distanceCoveredMeters: distanceCoveredMeters ?? this.distanceCoveredMeters,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
      isOverAverageSpeed: isOverAverageSpeed ?? this.isOverAverageSpeed,
      remainingMeters: remainingMeters ?? this.remainingMeters,
      targetRemainingSeconds: targetRemainingSeconds ?? this.targetRemainingSeconds,
    );
  }

  @override
  List<Object?> get props => [
        isActive,
        corridor,
        startTime,
        lastPosition,
        distanceCoveredMeters,
        elapsedSeconds,
        averageSpeedKmh,
        isOverAverageSpeed,
        remainingMeters,
        targetRemainingSeconds,
      ];
}

/// Máquina de estados determinística para fiscalização e cálculo de velocidade média em tempo real.
class SectionControlMachine {
  final List<AverageSpeedCorridor> corridors;
  final double speedToleranceKmh;

  SectionControlState _state = const SectionControlState();

  SectionControlMachine({
    required this.corridors,
    this.speedToleranceKmh = 5.0,
  });

  SectionControlState get state => _state;

  /// Atualiza o rastreamento a cada coordenada do veículo.
  SectionControlResult? updatePosition(VehiclePosition position) {
    if (!_state.isActive) {
      // 1. Verifica se o condutor está ingressando em algum trecho cadastrado
      for (final corridor in corridors) {
        final distToStart = haversineDistance(
          position.latitude,
          position.longitude,
          corridor.startPoi.latitude,
          corridor.startPoi.longitude,
        );

        final directionMatches = corridor.startPoi.direction == null ||
            isDirectionMatching(position.bearing, corridor.startPoi.direction);

        // Raio de ativação do pórtico A: até 80 metros
        if (distToStart <= 80.0 && directionMatches) {
          _state = SectionControlState(
            isActive: true,
            corridor: corridor,
            startTime: position.timestamp,
            lastPosition: position,
            distanceCoveredMeters: 0.0,
            elapsedSeconds: 0,
            averageSpeedKmh: position.speedKmh,
            isOverAverageSpeed: position.speedKmh > (corridor.speedLimitKmh + speedToleranceKmh),
            remainingMeters: corridor.lengthMeters,
            targetRemainingSeconds: (corridor.lengthMeters / (corridor.speedLimitKmh / 3.6)).round(),
          );
          return null;
        }
      }
      return null;
    }

    final corridor = _state.corridor!;
    final now = position.timestamp;
    final elapsedSec = math.max(1, now.difference(_state.startTime!).inSeconds);

    // Timeout de segurança se o condutor desviar ou estacionar (> 30 minutos)
    if (elapsedSec > 1800) {
      reset();
      return null;
    }

    // Odômetro por incremento geodésico
    double distDelta = 0.0;
    if (_state.lastPosition != null) {
      distDelta = haversineDistance(
        _state.lastPosition!.latitude,
        _state.lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
    }

    // Se o salto de distância for absurdo (> 10km em 1 segundo), aborta por GPS glitch
    if (distDelta > 10000.0) {
      reset();
      return null;
    }

    final totalDist = _state.distanceCoveredMeters + distDelta;
    final avgSpeedKmh = (totalDist / elapsedSec) * 3.6;
    final isOverSpeed = avgSpeedKmh > (corridor.speedLimitKmh + speedToleranceKmh);
    final remainingMeters = math.max(0.0, corridor.lengthMeters - totalDist);

    // Tempo total mínimo para percorrer o trecho sem infração
    final minTotalSeconds = (corridor.lengthMeters / (corridor.speedLimitKmh / 3.6)).round();
    final targetRemainingSeconds = math.max(0, minTotalSeconds - elapsedSec);

    // 2. Verifica se alcançou o pórtico de saída B
    final distToEnd = haversineDistance(
      position.latitude,
      position.longitude,
      corridor.endPoi.latitude,
      corridor.endPoi.longitude,
    );

    final reachedEnd = distToEnd <= 80.0 || (remainingMeters <= 30.0 && totalDist >= corridor.lengthMeters * 0.85);

    if (reachedEnd) {
      final result = SectionControlResult(
        corridorId: corridor.id,
        isCompleted: true,
        averageSpeedKmh: avgSpeedKmh,
        isOverSpeed: isOverSpeed,
        elapsedSeconds: elapsedSec,
        distanceMeters: totalDist,
      );
      reset();
      return result;
    }

    _state = _state.copyWith(
      lastPosition: position,
      distanceCoveredMeters: totalDist,
      elapsedSeconds: elapsedSec,
      averageSpeedKmh: avgSpeedKmh,
      isOverAverageSpeed: isOverSpeed,
      remainingMeters: remainingMeters,
      targetRemainingSeconds: targetRemainingSeconds,
    );

    return null;
  }

  void reset() {
    _state = const SectionControlState();
  }
}