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

      // 35 segundos parado: transiciona para modo estacionário (mantendo <= 1000ms para tempo quase real)
      final t2 = t0.add(const Duration(seconds: 35));
      sampler.updateSpeed(0.0, timestamp: t2);
      expect(sampler.isStationary, isTrue);
      expect(sampler.recommendedIntervalMs, equals(1000));
      expect(sampler.recommendedDistanceFilterMeters, equals(2));
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

    test('BUG #36 REGRESSÃO: sequência de 10 coordenadas oscilando em repouso (< 2 km/h) deve manter distância acumulada estritamente zero', () {
      // Coordenada base (Marco Zero da Praça da Sé, SP)
      const baseLat = -23.550520;
      const baseLon = -46.633308;
      final startTime = DateTime(2026, 10, 30, 10, 0, 0);

      // Simula 10 amostras de GPS com jitter de 1 a 2 metros e velocidade 0 km/h
      final jitterOffsets = [
        [0.0, 0.0],
        [0.00001, 0.00001],   // ~1.5m
        [-0.00001, 0.0],       // ~1.1m
        [0.000015, -0.00001],  // ~1.9m
        [0.0, 0.000012],       // ~1.3m
        [-0.000012, -0.00001], // ~1.8m
        [0.000008, 0.00001],   // ~1.4m
        [-0.000005, 0.0],      // ~0.6m
        [0.00001, -0.000008],  // ~1.3m
        [0.0, 0.0],            // retorna à origem
      ];

      for (var i = 0; i < jitterOffsets.length; i++) {
        final offset = jitterOffsets[i];
        final deltaDist = sampler.updateCoordinate(
          baseLat + offset[0],
          baseLon + offset[1],
          0.0,
          timestamp: startTime.add(Duration(seconds: i)),
        );
        expect(deltaDist, equals(0.0), reason: 'Amostra $i com jitter não deve pontuar deslocamento');
      }

      // Distância acumulada deve ser estritamente 0.0
      expect(sampler.accumulatedDistanceMeters, equals(0.0));
    });

    test('deslocamento real com velocidade > 2 km/h ou salto > 3m deve acumular distância normalmente', () {
      const baseLat = -23.550520;
      const baseLon = -46.633308;
      final t0 = DateTime(2026, 10, 30, 10, 0, 0);

      // 1. Posição inicial
      sampler.updateCoordinate(baseLat, baseLon, 0.0, timestamp: t0);
      expect(sampler.accumulatedDistanceMeters, equals(0.0));

      // 2. Deslocamento real do veículo a 40 km/h (~100m)
      const nextLat = -23.551420; // ~100m ao sul
      const nextLon = -46.633308;
      final dist = sampler.updateCoordinate(nextLat, nextLon, 40.0, timestamp: t0.add(const Duration(seconds: 1)));

      expect(dist, greaterThan(90.0));
      expect(sampler.accumulatedDistanceMeters, closeTo(100.0, 10.0));
    });
  });
}
