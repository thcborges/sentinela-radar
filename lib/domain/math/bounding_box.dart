import 'dart:math' as math;
import 'haversine.dart';

/// Representação de uma Bounding Box retangular sobre coordenadas WGS84,
/// otimizada para consultas espaciais de índice SQLite R*Tree.
class GeoBoundingBox {
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  const GeoBoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });

  /// Verifica se uma coordenada [lat, lon] cai estritamente dentro da bounding box.
  bool contains(double lat, double lon) {
    return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
  }

  @override
  String toString() =>
      'GeoBoundingBox(lat: [$minLat, $maxLat], lon: [$minLon, $maxLon])';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoBoundingBox &&
          runtimeType == other.runtimeType &&
          minLat == other.minLat &&
          maxLat == other.maxLat &&
          minLon == other.minLon &&
          maxLon == other.maxLon;

  @override
  int get hashCode => Object.hash(minLat, maxLat, minLon, maxLon);
}

/// Calcula uma [GeoBoundingBox] centrada em [centerLat, centerLon] com raio [radiusMeters].
///
/// Lança [ArgumentError] se [radiusMeters] for menor ou igual a zero.
GeoBoundingBox calculateBoundingBox(
  double centerLat,
  double centerLon,
  double radiusMeters,
) {
  if (radiusMeters <= 0.0) {
    throw ArgumentError.value(
      radiusMeters,
      'radiusMeters',
      'O raio de busca deve ser estritamente maior que zero.',
    );
  }

  // Variação angular de latitude
  final deltaLatRad = radiusMeters / earthRadiusMeters;
  final deltaLatDeg = radiansToDegrees(deltaLatRad);

  final minLat = (centerLat - deltaLatDeg).clamp(-90.0, 90.0);
  final maxLat = (centerLat + deltaLatDeg).clamp(-90.0, 90.0);

  // Variação angular de longitude proporcional ao cosseno da latitude
  final cosLat = math.cos(degreesToRadians(centerLat)).abs();
  final double deltaLonDeg;
  if (cosLat < 1e-6) {
    // Próximo aos polos, a longitude abrange todo o globo
    deltaLonDeg = 180.0;
  } else {
    final deltaLonRad = radiusMeters / (earthRadiusMeters * cosLat);
    deltaLonDeg = radiansToDegrees(deltaLonRad);
  }

  final minLon = (centerLon - deltaLonDeg).clamp(-180.0, 180.0);
  final maxLon = (centerLon + deltaLonDeg).clamp(-180.0, 180.0);

  return GeoBoundingBox(
    minLat: minLat,
    maxLat: maxLat,
    minLon: minLon,
    maxLon: maxLon,
  );
}
