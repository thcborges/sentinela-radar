import 'package:sentinela/core/geo/bounding_box.dart';
import 'package:sentinela/core/geo/haversine.dart';
import 'package:test/test.dart';

void main() {
  group('BoundingBox Calculator', () {
    test('deve calcular bounding box com delta positivo para raio > 0', () {
      const lat = -23.550520;
      const lon = -46.633308;
      const radiusMeters = 1000.0;

      final bbox = calculateBoundingBox(lat, lon, radiusMeters);

      expect(bbox.minLat, lessThan(lat));
      expect(bbox.maxLat, greaterThan(lat));
      expect(bbox.minLon, lessThan(lon));
      expect(bbox.maxLon, greaterThan(lon));
    });

    test('bounding box de 1000m deve conter qualquer ponto em raio de 1000m', () {
      const centerLat = -23.550520;
      const centerLon = -46.633308;
      const radiusMeters = 1000.0;

      final bbox = calculateBoundingBox(centerLat, centerLon, radiusMeters);

      // Pontos cardeais a 900m
      // 1 grau lat ~ 111195m => 900m ~ 0.00809 graus
      const deltaLat900m = 900.0 / 111195.0;
      final northPointLat = centerLat + deltaLat900m;
      final southPointLat = centerLat - deltaLat900m;

      expect(haversineDistance(centerLat, centerLon, northPointLat, centerLon), closeTo(900.0, 5.0));
      expect(bbox.contains(northPointLat, centerLon), isTrue);
      expect(bbox.contains(southPointLat, centerLon), isTrue);

      // Ponto fora (a 1200m)
      const deltaLat1200m = 1200.0 / 111195.0;
      final farPointLat = centerLat + deltaLat1200m;
      expect(bbox.contains(farPointLat, centerLon), isFalse);
    });

    test('deve limitar latitude aos polos (-90 e +90)', () {
      final nearNorthPole = calculateBoundingBox(89.99, 0.0, 50000.0);
      expect(nearNorthPole.maxLat, lessThanOrEqualTo(90.0));

      final nearSouthPole = calculateBoundingBox(-89.99, 0.0, 50000.0);
      expect(nearSouthPole.minLat, greaterThanOrEqualTo(-90.0));
    });

    test('raio zero ou negativo deve lançar ArgumentError', () {
      expect(() => calculateBoundingBox(0.0, 0.0, 0.0), throwsArgumentError);
      expect(() => calculateBoundingBox(0.0, 0.0, -100.0), throwsArgumentError);
    });

    test('deve lidar com cálculo exatamente no polo norte (cosLat < 1e-6)', () {
      final polarBbox = calculateBoundingBox(90.0, 0.0, 1000.0);
      expect(polarBbox.minLon, equals(-180.0));
      expect(polarBbox.maxLon, equals(180.0));
      expect(polarBbox.maxLat, equals(90.0));
    });

    test('GeoBoundingBox deve suportar igualdade por valor, hashCode e toString', () {
      const b1 = GeoBoundingBox(minLat: -10, maxLat: 10, minLon: -20, maxLon: 20);
      const b2 = GeoBoundingBox(minLat: -10, maxLat: 10, minLon: -20, maxLon: 20);
      const b3 = GeoBoundingBox(minLat: -10, maxLat: 11, minLon: -20, maxLon: 20);

      expect(b1, equals(b2));
      expect(b1.hashCode, equals(b2.hashCode));
      expect(b1 == b3, isFalse);
      expect(b1.toString(), contains('GeoBoundingBox'));
    });
  });
}
