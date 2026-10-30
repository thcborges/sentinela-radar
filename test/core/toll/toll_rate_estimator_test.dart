import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/toll/toll_rate_estimator.dart';
import 'package:sentinela/features/stats/models/passage_record.dart';

void main() {
  group('TollRateEstimator & TripCost (BDD - Tarifação de Pedágio e Free Flow)', () {
    const estimator = TollRateEstimator();

    test('deve retornar 0.0 para POIs que não sejam praça de pedágio ou Free Flow', () {
      const radar = PoiPoint(
        id: 1,
        latitude: -23.5,
        longitude: -46.6,
        type: PoiType.fixedRadar,
        speedLimit: 60,
      );

      expect(estimator.estimateToll(radar), equals(0.0));
      expect(estimator.estimateToll(radar, category: VehicleCategory.motorcycle), equals(0.0));
    });

    test('deve estimar tarifa padrão de Free Flow (R\$ 4,20 base) para cada categoria veicular', () {
      const freeFlow = PoiPoint(
        id: 101,
        latitude: -23.1,
        longitude: -46.2,
        type: PoiType.freeFlowToll,
        roadName: 'SP-099 Rod. dos Tamoios',
      );

      expect(estimator.estimateToll(freeFlow, category: VehicleCategory.car), equals(4.20));
      expect(estimator.estimateToll(freeFlow, category: VehicleCategory.motorcycle), equals(2.10));
      expect(estimator.estimateToll(freeFlow, category: VehicleCategory.commercial), equals(8.40));
      expect(estimator.estimateToll(freeFlow, category: VehicleCategory.heavyTruck), equals(16.80));
    });

    test('deve estimar tarifa padrão de Pedágio Convencional (R\$ 8,50 base) para cada categoria', () {
      const tollBooth = PoiPoint(
        id: 102,
        latitude: -23.2,
        longitude: -46.3,
        type: PoiType.tollBooth,
        roadName: 'SP-160 Rod. dos Imigrantes',
      );

      expect(estimator.estimateToll(tollBooth, category: VehicleCategory.car), equals(8.50));
      expect(estimator.estimateToll(tollBooth, category: VehicleCategory.motorcycle), equals(4.25));
      expect(estimator.estimateToll(tollBooth, category: VehicleCategory.commercial), equals(17.00));
      expect(estimator.estimateToll(tollBooth, category: VehicleCategory.heavyTruck), equals(34.00));
    });

    test('deve aceitar tabela com tarifa personalizada por POI id', () {
      final customEstimator = TollRateEstimator(
        customPoiRates: {
          500: 15.00,
        },
      );

      const customToll = PoiPoint(
        id: 500,
        latitude: -23.3,
        longitude: -46.4,
        type: PoiType.tollBooth,
        roadName: 'Ecopistas KM 32',
      );

      expect(customEstimator.estimateToll(customToll, category: VehicleCategory.car), equals(15.00));
      expect(customEstimator.estimateToll(customToll, category: VehicleCategory.motorcycle), equals(7.50));
    });

    test('deve calcular resumo de viagem (TripTollSummary) acumulando custos e contagens', () {
      final passages = [
        PassageRecord(
          poiId: 101,
          poiType: PoiType.freeFlowToll,
          vehicleSpeedKmh: 90,
          timestamp: DateTime(2026, 10, 30, 8, 0),
          isOverSpeed: false,
          roadName: 'Tamoios Free Flow 1',
          tollFee: 4.20,
        ),
        PassageRecord(
          poiId: 102,
          poiType: PoiType.freeFlowToll,
          vehicleSpeedKmh: 95,
          timestamp: DateTime(2026, 10, 30, 8, 30),
          isOverSpeed: false,
          roadName: 'Tamoios Free Flow 2',
          tollFee: 4.20,
        ),
        PassageRecord(
          poiId: 201,
          poiType: PoiType.tollBooth,
          vehicleSpeedKmh: 40,
          timestamp: DateTime(2026, 10, 30, 9, 0),
          isOverSpeed: false,
          roadName: 'Pedágio Convencional',
          tollFee: 8.50,
        ),
        PassageRecord(
          poiId: 301,
          poiType: PoiType.fixedRadar,
          vehicleSpeedKmh: 60,
          timestamp: DateTime(2026, 10, 30, 9, 30),
          isOverSpeed: false,
          roadName: 'Radar Comum',
        ),
      ];

      final summary = estimator.calculateTripSummary(passages);

      expect(summary.totalCost, closeTo(16.90, 0.01));
      expect(summary.freeFlowCount, equals(2));
      expect(summary.tollBoothCount, equals(1));
      expect(summary.totalTollPoints, equals(3));
      expect(summary.formatCurrency(), equals('R\$ 16,90'));
      expect(summary.formatCurrency(amount: 5.5), equals('R\$ 5,50'));
    });
  });
}