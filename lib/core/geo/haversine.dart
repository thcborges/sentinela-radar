import 'dart:math' as math;

/// Raio médio volumétrico da Terra em metros (padrão WGS84).
const double earthRadiusMeters = 6371000.0;

/// Converte graus para radianos.
double degreesToRadians(double degrees) => degrees * (math.pi / 180.0);

/// Converte radianos para graus.
double radiansToDegrees(double radians) => radians * (180.0 / math.pi);

/// Calcula a distância geodésica em metros entre dois pontos geográficos
/// especificados em latitude e longitude decimais (WGS84).
double haversineDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  if (lat1 == lat2 && lon1 == lon2) {
    return 0.0;
  }

  final phi1 = degreesToRadians(lat1);
  final phi2 = degreesToRadians(lat2);
  final deltaPhi = degreesToRadians(lat2 - lat1);
  final deltaLambda = degreesToRadians(lon2 - lon1);

  final sinDeltaPhiHalf = math.sin(deltaPhi / 2.0);
  final sinDeltaLambdaHalf = math.sin(deltaLambda / 2.0);

  final a = sinDeltaPhiHalf * sinDeltaPhiHalf +
      math.cos(phi1) * math.cos(phi2) * sinDeltaLambdaHalf * sinDeltaLambdaHalf;

  // Garante que o argumento de atan2 e sqrt não sofra com imprecisão de ponto flutuante
  final clampedA = a.clamp(0.0, 1.0);
  final c = 2.0 * math.atan2(math.sqrt(clampedA), math.sqrt(1.0 - clampedA));

  return earthRadiusMeters * c;
}
