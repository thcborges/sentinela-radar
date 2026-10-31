import 'dart:math' as math;
import 'haversine.dart';

/// Normaliza um ângulo em graus para o intervalo contínuo [0, 360).
double normalizeBearing(num degrees) {
  final normalized = degrees.toDouble() % 360.0;
  return normalized < 0.0 ? normalized + 360.0 : normalized;
}

/// Calcula o rumo inicial (bearing/azimute) em graus de [lat1, lon1] até [lat2, lon2].
/// O resultado é sempre normalizado no intervalo [0, 360), onde 0° = Norte,
/// 90° = Leste, 180° = Sul e 270° = Oeste.
double initialBearing(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  final phi1 = degreesToRadians(lat1);
  final phi2 = degreesToRadians(lat2);
  final deltaLambda = degreesToRadians(lon2 - lon1);

  final y = math.sin(deltaLambda) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

  final radians = math.atan2(y, x);
  return normalizeBearing(radiansToDegrees(radians));
}

/// Retorna a menor diferença angular (em graus) entre dois rumos no círculo [0, 180].
double bearingDifference(num b1, num b2) {
  final diff = (normalizeBearing(b1) - normalizeBearing(b2)).abs();
  return math.min(diff, 360.0 - diff);
}

/// Verifica se o rumo do veículo coincide com a direção cadastrada do POI dentro de
/// uma margem de tolerância.
///
/// Se [targetDirection] for nulo, o ponto é considerado omnidirecional (ex: semáforos
/// de cruzamento sem sentido único fixado) e retorna `true`.
bool isDirectionMatching(
  double vehicleBearing,
  num? targetDirection, {
  double toleranceDegrees = 35.0,
}) {
  if (targetDirection == null) {
    return true;
  }
  return bearingDifference(vehicleBearing, targetDirection) <= toleranceDegrees;
}

/// Verifica se um ponto geográfico [targetLat, targetLon] está situado à frente do
/// veículo [vehicleLat, vehicleLon] que trafega com o rumo [vehicleBearing],
/// respeitando o cone frontal de abertura [aheadToleranceDegrees].
bool isPointAhead(
  double vehicleLat,
  double vehicleLon,
  double vehicleBearing,
  double targetLat,
  double targetLon, {
  double aheadToleranceDegrees = 40.0,
}) {
  final bearingToTarget = initialBearing(
    vehicleLat,
    vehicleLon,
    targetLat,
    targetLon,
  );
  return bearingDifference(vehicleBearing, bearingToTarget) <=
      aheadToleranceDegrees;
}
