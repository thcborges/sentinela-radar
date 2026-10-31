/// Controlador de taxa adaptativa de amostragem de GPS para otimização de bateria e CPU.
/// Quando o veículo está parado ou em velocidade mínima (< 5 km/h) por um período
/// prolongado (ex: semáforo, engarrafamento ou parada), reduz a cadência de
/// consultas espaciais ao índice SQLite R*Tree.
class AdaptiveGpsSampler {
  final Duration stationaryThreshold;
  final double stationarySpeedThresholdKmh;

  bool _isStationary = false;
  DateTime? _stationarySince;

  AdaptiveGpsSampler({
    this.stationaryThreshold = const Duration(seconds: 30),
    this.stationarySpeedThresholdKmh = 5.0,
  });

  bool get isStationary => _isStationary;

  /// Intervalo recomendado em milissegundos para polling e consultas espaciais.
  int get recommendedIntervalMs => _isStationary ? 3000 : 1000;

  /// Filtro mínimo de deslocamento recomendado em metros para o chip GPS.
  int get recommendedDistanceFilterMeters => _isStationary ? 10 : 2;

  /// Atualiza o estado do sampler a partir da telemetria veicular.
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

  /// Redefine o sampler para o modo padrão de alta resolução.
  void reset() {
    _isStationary = false;
    _stationarySince = null;
  }
}
