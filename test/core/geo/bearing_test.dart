import 'package:sentinela/core/geo/bearing.dart';
import 'package:test/test.dart';

void main() {
  group('Bearing and Angular Utilities', () {
    test('normalizeBearing deve manter valores no intervalo [0, 360)', () {
      expect(normalizeBearing(0), closeTo(0.0, 0.001));
      expect(normalizeBearing(360), closeTo(0.0, 0.001));
      expect(normalizeBearing(720), closeTo(0.0, 0.001));
      expect(normalizeBearing(-10), closeTo(350.0, 0.001));
      expect(normalizeBearing(-370), closeTo(350.0, 0.001));
      expect(normalizeBearing(370), closeTo(10.0, 0.001));
    });

    test('initialBearing deve calcular rumo cardeal exato nos 4 quadrantes', () {
      // Norte puro (0°)
      final north = initialBearing(0.0, 0.0, 1.0, 0.0);
      expect(north, closeTo(0.0, 0.1));

      // Leste puro (90°)
      final east = initialBearing(0.0, 0.0, 0.0, 1.0);
      expect(east, closeTo(90.0, 0.1));

      // Sul puro (180°)
      final south = initialBearing(1.0, 0.0, 0.0, 0.0);
      expect(south, closeTo(180.0, 0.1));

      // Oeste puro (270°)
      final west = initialBearing(0.0, 1.0, 0.0, 0.0);
      expect(west, closeTo(270.0, 0.1));
    });

    test('bearingDifference deve retornar a menor distância angular no círculo', () {
      expect(bearingDifference(10, 20), closeTo(10.0, 0.001));
      expect(bearingDifference(20, 10), closeTo(10.0, 0.001));
      expect(bearingDifference(350, 10), closeTo(20.0, 0.001));
      expect(bearingDifference(10, 350), closeTo(20.0, 0.001));
      expect(bearingDifference(0, 180), closeTo(180.0, 0.001));
      expect(bearingDifference(359, 1), closeTo(2.0, 0.001));
    });

    test('isDirectionMatching deve aceitar pontos omnidirecionais (null)', () {
      expect(isDirectionMatching(90.0, null), isTrue);
      expect(isDirectionMatching(180.0, null), isTrue);
    });

    test('isDirectionMatching deve validar sentido compatível com tolerância', () {
      // Rumo do carro = 50°, radar = 45°, tolerância = 35° -> dentro (5° <= 35°)
      expect(isDirectionMatching(50.0, 45, toleranceDegrees: 35.0), isTrue);

      // Cruzando o meridiano/360°: carro = 355°, radar = 10° -> dentro (15° <= 35°)
      expect(isDirectionMatching(355.0, 10, toleranceDegrees: 35.0), isTrue);

      // Via perpendicular (cruzamento a 90°): carro = 0°, radar = 90° -> fora
      expect(isDirectionMatching(0.0, 90, toleranceDegrees: 35.0), isFalse);

      // Sentido contrário em pista dupla: carro = 0° (Norte), radar = 180° (Sul) -> fora
      expect(isDirectionMatching(0.0, 180, toleranceDegrees: 35.0), isFalse);
    });

    test('isPointAhead deve detectar se o POI está no cone frontal do veículo', () {
      // Carro em (0, 0) trafegando para o Norte (bearing = 0°)
      const carLat = 0.0;
      const carLon = 0.0;
      const carBearing = 0.0;

      // Ponto 500m ao Norte -> diretamente à frente
      expect(
        isPointAhead(carLat, carLon, carBearing, 0.005, 0.0, aheadToleranceDegrees: 40.0),
        isTrue,
      );

      // Ponto ao Norte ligeiramente a Leste (azimute ~15°) -> à frente no cone
      expect(
        isPointAhead(carLat, carLon, carBearing, 0.005, 0.0013, aheadToleranceDegrees: 40.0),
        isTrue,
      );

      // Ponto ao Sul (atrás do carro) -> azimute 180° -> fora
      expect(
        isPointAhead(carLat, carLon, carBearing, -0.005, 0.0, aheadToleranceDegrees: 40.0),
        isFalse,
      );

      // Ponto na rua transversal à direita (90°) com cone de 40° -> fora
      expect(
        isPointAhead(carLat, carLon, carBearing, 0.0, 0.005, aheadToleranceDegrees: 40.0),
        isFalse,
      );
    });
  });
}
