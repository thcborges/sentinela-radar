import 'dart:async';
import 'dart:math' as math;
import '../models/poi_model.dart';

/// Status operacional da recepção de satélite e odometria inercial.
enum DeadReckoningStatus {
  /// Buscando sinal de GPS inicial.
  searchingSignal,

  /// Sinal de satélite com fix preciso e confiável.
  gpsLocked,

  /// Operando em navegação inercial estimada (Túneis, garagens ou perda transitória de GPS).
  deadReckoning,
}

/// Motor de Odometria Inercial / Projeção Cinemática de Posição (Dead Reckoning).
///
/// Mantém o rastreamento ativo e o disparo regressivo de alertas em locais sem
/// cobertura de sinal de satélite (ex: Túneis Ayrton Senna, Rebouças, pistas cobertas).
class DeadReckoningEngine {
  static const double earthRadiusMeters = 6371000.0;

  final double gpsLossTimeoutSeconds;
  final double maxAcceptableAccuracyMeters;
  final double maxDeadReckoningDurationSeconds;
  final double speedDampingPerSecond;

  DeadReckoningStatus _status = DeadReckoningStatus.searchingSignal;
  VehiclePosition? _lastGpsFix;
  VehiclePosition? _lastEstimatedPosition;
  DateTime? _deadReckoningStartTime;

  final StreamController<DeadReckoningStatus> _statusController =
      StreamController<DeadReckoningStatus>.broadcast();

  DeadReckoningEngine({
    this.gpsLossTimeoutSeconds = 2.0,
    this.maxAcceptableAccuracyMeters = 40.0,
    this.maxDeadReckoningDurationSeconds = 300.0,
    this.speedDampingPerSecond = 0.995,
  });

  /// Status atual do subsistema de localização.
  DeadReckoningStatus get status => _status;

  /// Indica se a navegação inercial em túnel/sem GPS está em andamento.
  bool get isDeadReckoningActive => _status == DeadReckoningStatus.deadReckoning;

  /// Última posição válida (seja GPS real ou posição extrapolada).
  VehiclePosition? get lastKnownPosition => _lastEstimatedPosition ?? _lastGpsFix;

  /// Stream reativa de notificações de transição de status.
  Stream<DeadReckoningStatus> get statusStream => _statusController.stream;

  /// Alimenta o motor com nova posição recebida do hardware de GPS.
  /// Retorna [true] se o fix foi aceito com precisão suficiente, ou [false] se foi rejeitado.
  bool updateWithGps(VehiclePosition position) {
    if (position.accuracyMeters > maxAcceptableAccuracyMeters) {
      if (_lastGpsFix != null && _lastGpsFix!.speedKmh > 5.0) {
        _transitionTo(DeadReckoningStatus.deadReckoning);
      }
      return false;
    }

    _lastGpsFix = position;
    _lastEstimatedPosition = position;
    _deadReckoningStartTime = null;
    _transitionTo(DeadReckoningStatus.gpsLocked);
    return true;
  }

  /// Projeta a posição do veículo cinematicamente para o instante [now].
  ///
  /// Retorna [VehiclePosition] extrapolado ou [null] caso o limite máximo de
  /// tempo de navegação inercial tenha expirado sem recuperação de sinal.
  VehiclePosition? projectPosition(DateTime now) {
    if (_lastGpsFix == null) {
      _transitionTo(DeadReckoningStatus.searchingSignal);
      return null;
    }

    final anchor = _lastEstimatedPosition ?? _lastGpsFix!;
    final totalSecondsWithoutGps =
        now.difference(_lastGpsFix!.timestamp).inMilliseconds / 1000.0;

    if (totalSecondsWithoutGps > maxDeadReckoningDurationSeconds) {
      _transitionTo(DeadReckoningStatus.searchingSignal);
      _lastEstimatedPosition = null;
      return null;
    }

    final deltaSeconds = now.difference(anchor.timestamp).inMilliseconds / 1000.0;
    if (deltaSeconds <= 0.0) {
      return anchor;
    }

    _deadReckoningStartTime ??= anchor.timestamp;
    _transitionTo(DeadReckoningStatus.deadReckoning);

    // Damping da velocidade
    final currentSpeed = anchor.speedKmh * math.pow(speedDampingPerSecond, deltaSeconds);
    final speedMetersPerSecond = currentSpeed / 3.6;
    final distanceMeters = speedMetersPerSecond * deltaSeconds;

    // Projeção geodésica Great-Circle
    final projectedCoord = _computeGreatCircleDestination(
      anchor.latitude,
      anchor.longitude,
      distanceMeters,
      anchor.bearing,
    );

    final estimatedAccuracy = math.min(150.0, anchor.accuracyMeters + (2.0 * deltaSeconds));

    final projected = VehiclePosition(
      latitude: projectedCoord.$1,
      longitude: projectedCoord.$2,
      speedKmh: currentSpeed,
      bearing: anchor.bearing,
      accuracyMeters: estimatedAccuracy,
      timestamp: now,
    );

    _lastEstimatedPosition = projected;
    return projected;
  }

  /// Permite calibração manual ou via sensor inercial (ex: giroscópio/acelerômetro) da velocidade e rumo.
  void calibrateSensorVelocity({required double speedKmh, required double bearing}) {
    if (_lastEstimatedPosition != null) {
      _lastEstimatedPosition = VehiclePosition(
        latitude: _lastEstimatedPosition!.latitude,
        longitude: _lastEstimatedPosition!.longitude,
        speedKmh: speedKmh,
        bearing: bearing,
        accuracyMeters: _lastEstimatedPosition!.accuracyMeters,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Limpa o estado interno e retorna ao status de busca inicial.
  void reset() {
    _lastGpsFix = null;
    _lastEstimatedPosition = null;
    _deadReckoningStartTime = null;
    _transitionTo(DeadReckoningStatus.searchingSignal);
  }

  /// Libera recursos da stream reativa.
  void dispose() {
    _statusController.close();
  }

  void _transitionTo(DeadReckoningStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      if (!_statusController.isClosed) {
        _statusController.add(newStatus);
      }
    }
  }

  /// Projeção esférica (Haversine inverso / Great-Circle Direct Problem)
  (double, double) _computeGreatCircleDestination(
    double latDeg,
    double lonDeg,
    double distanceMeters,
    double bearingDeg,
  ) {
    final delta = distanceMeters / earthRadiusMeters;
    final thetaRad = bearingDeg * (math.pi / 180.0);
    final phi1 = latDeg * (math.pi / 180.0);
    final lambda1 = lonDeg * (math.pi / 180.0);

    final phi2 = math.asin(
      math.sin(phi1) * math.cos(delta) +
          math.cos(phi1) * math.sin(delta) * math.cos(thetaRad),
    );

    final lambda2 = lambda1 +
        math.atan2(
          math.sin(thetaRad) * math.sin(delta) * math.cos(phi1),
          math.cos(delta) - math.sin(phi1) * math.sin(phi2),
        );

    final newLatDeg = phi2 * (180.0 / math.pi);
    var newLonDeg = lambda2 * (180.0 / math.pi);

    // Normaliza longitude [-180, 180]
    while (newLonDeg < -180.0) {
      newLonDeg += 360.0;
    }
    while (newLonDeg > 180.0) {
      newLonDeg -= 360.0;
    }

    return (newLatDeg, newLonDeg);
  }
}
