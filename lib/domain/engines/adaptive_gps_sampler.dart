import '../math/haversine.dart';

/// Controlador de taxa adaptativa de amostragem de GPS para otimização de bateria e CPU.
/// Quando o veículo está parado ou em velocidade mínima (< 5 km/h) por um período
/// prolongado (ex: semáforo, engarrafamento ou parada), reduz a cadência de
/// consultas espaciais ao índice SQLite R*Tree.
///
/// Também atua como filtro de banda morta (dead-band) geodésico para eliminar jitter
/// e ruído estocástico do sinal de GPS com veículo em repouso.
class AdaptiveGpsSampler {
  final Duration stationaryThreshold;
  final double stationarySpeedThresholdKmh;
  final double deadBandMeters;
  final double deadBandSpeedThresholdKmh;

  bool _isStationary = false;
  DateTime? _stationarySince;
  double _accumulatedDistanceMeters = 0.0;
  double? _lastLatitude;
  double? _lastLongitude;

  AdaptiveGpsSampler({
    this.stationaryThreshold = const Duration(seconds: 30),
    this.stationarySpeedThresholdKmh = 5.0,
    this.deadBandMeters = 3.0,
    this.deadBandSpeedThresholdKmh = 2.0,
  });

  bool get isStationary => _isStationary;
  double get accumulatedDistanceMeters => _accumulatedDistanceMeters;

  /// Intervalo recomendado em milissegundos para polling e consultas espaciais.
  int get recommendedIntervalMs => _isStationary ? 3000 : 1000;

  /// Filtro mínimo de deslocamento recomendado em metros para o chip GPS.
  int get recommendedDistanceFilterMeters => _isStationary ? 10 : 2;

  /// Atualiza o estado do sampler e calcula o deslocamento real aplicando filtro de banda morta.
  double updateCoordinate(
    double latitude,
    double longitude,
    double speedKmh, {
    DateTime? timestamp,
  }) {
    updateSpeed(speedKmh, timestamp: timestamp);

    if (_lastLatitude == null || _lastLongitude == null) {
      _lastLatitude = latitude;
      _lastLongitude = longitude;
      return 0.0;
    }

    final distDelta = haversineDistance(
      _lastLatitude!,
      _lastLongitude!,
      latitude,
      longitude,
    );

    // Dead-band geodésico: descarta variações micrométricas de jitter (< 3m) com veículo em repouso (< 2 km/h)
    if (speedKmh < deadBandSpeedThresholdKmh && distDelta < deadBandMeters) {
      return 0.0;
    }

    _accumulatedDistanceMeters += distDelta;
    _lastLatitude = latitude;
    _lastLongitude = longitude;
    return distDelta;
  }

  /// Atualiza a velocidade do sampler a partir da telemetria veicular.
  void updateSpeed(double speedKmh, {DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();

    if (speedKmh < stationarySpeedThresholdKmh) {
      _stationarySince ??= now;
      if (now.difference(_stationarySince!) >= stationaryThreshold) {
        _isStationary = true;
      }
    } else {
      _isStationary = false;
      _stationarySince = null;
    }
  }

  /// Redefine o sampler para o modo padrão de alta resolução e reseta odômetro.
  void reset() {
    _isStationary = false;
    _stationarySince = null;
    _accumulatedDistanceMeters = 0.0;
    _lastLatitude = null;
    _lastLongitude = null;
  }
}
