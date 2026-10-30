import 'package:sentinela/core/models/alert_distance_calculator.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:test/test.dart';

void main() {
  group('AlertDistanceCalculator', () {
    test('radar fixo e móvel a 0 km/h deve respeitar piso D_min de 200m', () {
      final distance = AlertDistanceCalculator.calculateAlertDistance(
        PoiType.fixedRadar,
        0.0,
      );
      expect(distance, equals(200.0));
    });

    test('radar fixo a 60 km/h deve disparar a ~250m (15 segundos)', () {
      final distance = AlertDistanceCalculator.calculateAlertDistance(
        PoiType.fixedRadar,
        60.0,
      );
      // 60 km/h = 16.666 m/s * 15s = 250m
      expect(distance, closeTo(250.0, 0.5));
    });

    test('radar fixo a 110 km/h deve disparar a ~458m', () {
      final distance = AlertDistanceCalculator.calculateAlertDistance(
        PoiType.fixedRadar,
        110.0,
      );
      // 110 km/h = 30.555 m/s * 15s = 458.33m
      expect(distance, closeTo(458.33, 0.5));
    });

    test('semáforo de sinal vermelho deve ter D_min de 180m', () {
      // 40 km/h = 11.11 m/s * 10s = 111.1m -> deve ficar em 180m
      final slow = AlertDistanceCalculator.calculateAlertDistance(
        PoiType.redLightCamera,
        40.0,
      );
      expect(slow, equals(180.0));

      // 70 km/h = 19.44 m/s * 10s = 194.4m -> dinâmico
      final fast = AlertDistanceCalculator.calculateAlertDistance(
        PoiType.redLightCamera,
        70.0,
      );
      expect(fast, closeTo(194.44, 0.5));
    });

    test('lombada física deve ter D_min de 80m e antecipação curta', () {
      final slow = AlertDistanceCalculator.calculateAlertDistance(
        PoiType.physicalSpeedBump,
        30.0,
      );
      expect(slow, equals(80.0));

      final fast = AlertDistanceCalculator.calculateAlertDistance(
        PoiType.physicalSpeedBump,
        50.0,
      );
      // 50 km/h = 13.888 m/s * 8s = 111.11m
      expect(fast, closeTo(111.11, 0.5));
    });

    test('praça de pedágio deve ter D_min de 800m', () {
      final normal = AlertDistanceCalculator.calculateAlertDistance(
        PoiType.tollBooth,
        100.0,
      );
      expect(normal, equals(800.0));

      final fast = AlertDistanceCalculator.calculateAlertDistance(
        PoiType.tollBooth,
        120.0,
      );
      // 120 km/h = 33.333 m/s * 25s = 833.33m
      expect(fast, closeTo(833.33, 0.5));
    });

    test('calculateApproachingDistance deve ser maior que a distância de alerta', () {
      final alertDist = AlertDistanceCalculator.calculateAlertDistance(
        PoiType.fixedRadar,
        60.0,
      );
      final approachingDist = AlertDistanceCalculator.calculateApproachingDistance(
        PoiType.fixedRadar,
        60.0,
      );

      expect(approachingDist, greaterThan(alertDist));
      expect(approachingDist, closeTo(alertDist * 1.5, 0.5));
    });
  });
}
