import 'package:sentinela/core/models/poi_model.dart';
import 'package:test/test.dart';

void main() {
  group('PoiType Enum and Classifications', () {
    test('PoiType.fromCode deve mapear corretamente todos os 9 códigos', () {
      expect(PoiType.fromCode(1), equals(PoiType.fixedRadar));
      expect(PoiType.fromCode(2), equals(PoiType.mobileRadar));
      expect(PoiType.fromCode(3), equals(PoiType.trafficLightRadar));
      expect(PoiType.fromCode(4), equals(PoiType.redLightCamera));
      expect(PoiType.fromCode(5), equals(PoiType.electronicSpeedBump));
      expect(PoiType.fromCode(6), equals(PoiType.physicalSpeedBump));
      expect(PoiType.fromCode(7), equals(PoiType.tollBooth));
      expect(PoiType.fromCode(8), equals(PoiType.freeFlowToll));
      expect(PoiType.fromCode(9), equals(PoiType.highwayPatrol));
    });

    test('código desconhecido deve retornar fixedRadar como fallback seguro', () {
      expect(PoiType.fromCode(999), equals(PoiType.fixedRadar));
      expect(PoiType.fromCode(-1), equals(PoiType.fixedRadar));
    });

    test('classificações booleanas de tipos de POI', () {
      expect(PoiType.fixedRadar.isSpeedEnforcement, isTrue);
      expect(PoiType.trafficLightRadar.isSpeedEnforcement, isTrue);
      expect(PoiType.redLightCamera.isSpeedEnforcement, isFalse);
      expect(PoiType.redLightCamera.isRedLightEnforcement, isTrue);
      expect(PoiType.trafficLightRadar.isRedLightEnforcement, isTrue);

      expect(PoiType.physicalSpeedBump.isSpeedBump, isTrue);
      expect(PoiType.electronicSpeedBump.isSpeedBump, isTrue);
      expect(PoiType.fixedRadar.isSpeedBump, isFalse);

      expect(PoiType.tollBooth.isToll, isTrue);
      expect(PoiType.freeFlowToll.isToll, isTrue);
      expect(PoiType.highwayPatrol.isToll, isFalse);
    });
  });

  group('PoiPoint Model', () {
    test('PoiPoint deve instanciar com atributos e ter suporte a igualdade por valor', () {
      const poi1 = PoiPoint(
        id: 101,
        type: PoiType.fixedRadar,
        latitude: -23.550520,
        longitude: -46.633308,
        speedLimit: 60,
        direction: 90,
        roadName: 'Av. Paulista',
        operator: 'CET-SP',
      );

      const poi2 = PoiPoint(
        id: 101,
        type: PoiType.fixedRadar,
        latitude: -23.550520,
        longitude: -46.633308,
        speedLimit: 60,
        direction: 90,
        roadName: 'Av. Paulista',
        operator: 'CET-SP',
      );

      expect(poi1, equals(poi2));
      expect(poi1.props, equals(poi2.props));
      expect(poi1.toleranceAngle, equals(35.0)); // valor padrão
      expect(poi1.roadName, equals('Av. Paulista'));
      expect(poi1.operator, equals('CET-SP'));
    });
  });

  group('VehiclePosition Model', () {
    test('VehiclePosition deve calcular velocidade em m/s e validar precisão do GPS', () {
      final now = DateTime(2026, 10, 30, 10, 0, 0);
      final accuratePos = VehiclePosition(
        latitude: -23.550520,
        longitude: -46.633308,
        speedKmh: 72.0,
        bearing: 45.0,
        accuracyMeters: 10.0,
        timestamp: now,
      );

      final accuratePos2 = VehiclePosition(
        latitude: -23.550520,
        longitude: -46.633308,
        speedKmh: 72.0,
        bearing: 45.0,
        accuracyMeters: 10.0,
        timestamp: now,
      );

      expect(accuratePos.speedMs, closeTo(20.0, 0.001));
      expect(accuratePos.isAccurate, isTrue);
      expect(accuratePos, equals(accuratePos2));
      expect(accuratePos.props, equals(accuratePos2.props));

      final noisyPos = VehiclePosition(
        latitude: -23.550520,
        longitude: -46.633308,
        speedKmh: 72.0,
        bearing: 45.0,
        accuracyMeters: 45.0, // Acima do teto de 35m
        timestamp: DateTime(2026, 10, 30, 10, 0, 0),
      );

      expect(noisyPos.isAccurate, isFalse);
    });
  });
}
