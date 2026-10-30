import 'package:sentinela/core/geo/haversine.dart';
import 'package:test/test.dart';

void main() {
  group('Haversine Distance Calculator', () {
    test('distância para o mesmo ponto deve ser zero', () {
      const lat = -23.550520;
      const lon = -46.633308;

      final distance = haversineDistance(lat, lon, lat, lon);

      expect(distance, closeTo(0.0, 0.001));
    });

    test('distância conhecida: Marco Zero (Sé) até MASP (~2630 metros)', () {
      // Praça da Sé, SP
      const seLat = -23.550520;
      const seLon = -46.633308;

      // MASP, Av. Paulista, SP
      const maspLat = -23.561414;
      const maspLon = -46.655881;

      final distance = haversineDistance(seLat, seLon, maspLat, maspLon);

      // Esperado: aproximadamente 2630 metros (tolerância de 30m para modelo esférico)
      expect(distance, closeTo(2630.0, 30.0));
    });

    test('distância de 1 grau de latitude deve ser aproximadamente 111.19 km', () {
      final distance = haversineDistance(0.0, 0.0, 1.0, 0.0);

      expect(distance, closeTo(111195.0, 500.0));
    });

    test('distância entre hemisférios opostos e cruzando o meridiano de Greenwich', () {
      // Londres (Norte, Greenwich)
      const londonLat = 51.5074;
      const londonLon = -0.1278;

      // Paris
      const parisLat = 48.8566;
      const parisLon = 2.3522;

      final distance = haversineDistance(londonLat, londonLon, parisLat, parisLon);

      // Distância Londres - Paris ~ 343.5 km
      expect(distance, closeTo(343500.0, 1500.0));
    });

    test('distância deve ser comutativa: d(A, B) == d(B, A)', () {
      const latA = -22.9068;
      const lonA = -43.1729; // Rio de Janeiro
      const latB = -23.5505;
      const lonB = -46.6333; // São Paulo

      final distAB = haversineDistance(latA, lonA, latB, lonB);
      final distBA = haversineDistance(latB, lonB, latA, lonA);

      expect(distAB, equals(distBA));
      expect(distAB, closeTo(360750.0, 500.0));
    });
  });
}
