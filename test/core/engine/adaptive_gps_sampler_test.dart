import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/adaptive_gps_sampler.dart';

void main() {
  group('AdaptiveGpsSampler Tests (BDD)', () {
    late AdaptiveGpsSampler sampler;

    setUp(() {
      sampler = AdaptiveGpsSampler(stationaryThreshold: const Duration(seconds: 30));
    });

    test('deve iniciar no modo ativo de alta frequência', () {
      expect(sampler.isStationary, isFalse);
      expect(sampler.recommendedIntervalMs, equals(1000));
      expect(sampler.recommendedDistanceFilterMeters, equals(2));
    });

    test('veículo em movimento (> 5 km/h) deve manter modo ativo', () {
      final t0 = DateTime(2026, 10, 30, 10, 0, 0);
      sampler.updateSpeed(60.0, timestamp: t0);

      final t1 = t0.add(const Duration(seconds: 40));
      sampler.updateSpeed(55.0, timestamp: t1);

      expect(sampler.isStationary, isFalse);
      expect(sampler.recommendedIntervalMs, equals(1000));
    });

    test('veículo parado (< 5 km/h) por mais de 30s deve entrar em modo economia', () {
      final t0 = DateTime(2026, 10, 30, 10, 0, 0);
      sampler.updateSpeed(0.0, timestamp: t0);
      expect(sampler.isStationary, isFalse);

      // 20 segundos parado: ainda não atingiu o threshold
      final t1 = t0.add(const Duration(seconds: 20));
      sampler.updateSpeed(2.0, timestamp: t1);
      expect(sampler.isStationary, isFalse);

      // 35 segundos parado: transiciona para modo estacionário / economia
      final t2 = t0.add(const Duration(seconds: 35));
      sampler.updateSpeed(0.0, timestamp: t2);
      expect(sampler.isStationary, isTrue);
      expect(sampler.recommendedIntervalMs, equals(3000));
      expect(sampler.recommendedDistanceFilterMeters, equals(10));
    });

    test('ao voltar a acelerar (>= 5 km/h) deve restaurar imediatamente alta frequência', () {
      final t0 = DateTime(2026, 10, 30, 10, 0, 0);
      sampler.updateSpeed(0.0, timestamp: t0);
      sampler.updateSpeed(0.0, timestamp: t0.add(const Duration(seconds: 40)));
      expect(sampler.isStationary, isTrue);

      // Retomada da marcha
      sampler.updateSpeed(15.0, timestamp: t0.add(const Duration(seconds: 42)));
      expect(sampler.isStationary, isFalse);
      expect(sampler.recommendedIntervalMs, equals(1000));
      expect(sampler.recommendedDistanceFilterMeters, equals(2));
    });

    test('reset deve restabelecer valores padrões', () {
      final t0 = DateTime(2026, 10, 30, 10, 0, 0);
      sampler.updateSpeed(0.0, timestamp: t0);
      sampler.updateSpeed(0.0, timestamp: t0.add(const Duration(seconds: 40)));
      expect(sampler.isStationary, isTrue);

      sampler.reset();
      expect(sampler.isStationary, isFalse);
      expect(sampler.recommendedIntervalMs, equals(1000));
    });
  });
}
