import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/models/vehicle_profile.dart';

void main() {
  group('VehicleProfile (Perfis de Veículos conforme Código de Trânsito Brasileiro)', () {
    test('deve criar perfis padrão para carro, moto e pesado', () {
      final car = VehicleProfile.car();
      expect(car.type, equals(VehicleType.car));
      expect(car.name, contains('Automóvel'));
      expect(car.lookaheadMultiplier, equals(1.0));
      expect(car.maxSpeedCapKmh, isNull);

      final moto = VehicleProfile.motorcycle();
      expect(moto.type, equals(VehicleType.motorcycle));
      expect(moto.name, contains('Moto'));
      expect(moto.lookaheadMultiplier, equals(0.95));
      expect(moto.maxSpeedCapKmh, isNull);

      final heavy = VehicleProfile.heavy();
      expect(heavy.type, equals(VehicleType.heavy));
      expect(heavy.name, contains('Pesado'));
      expect(heavy.lookaheadMultiplier, equals(1.40));
      expect(heavy.maxSpeedCapKmh, equals(90));
    });

    test('deve resolver limite de velocidade sem alteração para carros e motos em rodovias', () {
      final car = VehicleProfile.car();
      final moto = VehicleProfile.motorcycle();

      // Via de 110 km/h (ex: Rodovia dos Bandeirantes / Dutra)
      expect(car.resolveSpeedLimit(110), equals(110));
      expect(moto.resolveSpeedLimit(110), equals(110));

      // Via urbana de 60 km/h
      expect(car.resolveSpeedLimit(60), equals(60));
      expect(moto.resolveSpeedLimit(60), equals(60));
    });

    test('deve aplicar teto do CTB (90 km/h) para veículos pesados quando via for >= 100 km/h', () {
      final heavy = VehicleProfile.heavy();

      // Rodovia com 110 km/h para leves -> Pesado é limitado a 90 km/h pelo CTB
      expect(heavy.resolveSpeedLimit(110), equals(90));
      expect(heavy.resolveSpeedLimit(120), equals(90));

      // Rodovia com 80 km/h -> Mantém 80 km/h (já abaixo do teto)
      expect(heavy.resolveSpeedLimit(80), equals(80));

      // Via urbana de 50 km/h -> Mantém 50 km/h
      expect(heavy.resolveSpeedLimit(50), equals(50));
    });

    test('deve priorizar speedLimitHeavy explícito da base de dados quando fornecido', () {
      final heavy = VehicleProfile.heavy();

      // Ex: Rodovia com placa indicando expressamente "Caminhões: 80 km/h"
      expect(heavy.resolveSpeedLimit(100, speedLimitHeavy: 80), equals(80));

      // Para carro, speedLimitHeavy é ignorado
      final car = VehicleProfile.car();
      expect(car.resolveSpeedLimit(100, speedLimitHeavy: 80), equals(100));
    });

    test('deve serializar e desserializar para Map com suporte a copyWith e igualdade', () {
      final profile = VehicleProfile.heavy();
      final map = profile.toMap();

      expect(map['type'], equals('heavy'));
      expect(map['lookaheadMultiplier'], equals(1.40));
      expect(map['maxSpeedCapKmh'], equals(90));

      final restored = VehicleProfile.fromMap(map);
      expect(restored, equals(profile));

      final customized = profile.copyWith(
        name: 'Carreta Bitrem Custom',
        lookaheadMultiplier: 1.55,
      );
      expect(customized.name, equals('Carreta Bitrem Custom'));
      expect(customized.lookaheadMultiplier, equals(1.55));
      expect(customized.type, equals(VehicleType.heavy));
    });

    test('deve criar profile via fromType', () {
      expect(VehicleProfile.fromType(VehicleType.car).type, equals(VehicleType.car));
      expect(VehicleProfile.fromType(VehicleType.motorcycle).type, equals(VehicleType.motorcycle));
      expect(VehicleProfile.fromType(VehicleType.heavy).type, equals(VehicleType.heavy));
    });
  });
}
