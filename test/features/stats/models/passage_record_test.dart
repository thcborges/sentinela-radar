import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/features/stats/models/passage_record.dart';

void main() {
  group('PassageRecord Model', () {
    test('deve serializar toMap e deserializar fromMap com fidelidade de dados', () {
      final now = DateTime(2026, 10, 30, 11, 0, 0);
      final record = PassageRecord(
        id: 42,
        poiId: 100,
        poiType: PoiType.fixedRadar,
        vehicleSpeedKmh: 65.5,
        speedLimit: 60,
        timestamp: now,
        isOverSpeed: true,
        roadName: 'Av. Paulista',
        tollFee: 4.20,
      );

      final map = record.toMap();
      expect(map['id'], equals(42));
      expect(map['poi_id'], equals(100));
      expect(map['poi_type'], equals(1));
      expect(map['vehicle_speed'], equals(65.5));
      expect(map['speed_limit'], equals(60));
      expect(map['is_over_speed'], equals(1));
      expect(map['road_name'], equals('Av. Paulista'));
      expect(map['toll_fee'], equals(4.20));

      final reconstructed = PassageRecord.fromMap(map);
      expect(reconstructed, equals(record));
      expect(reconstructed.props, equals(record.props));
      expect(reconstructed.tollFee, equals(4.20));
    });

    test('StatsSummary props e cálculo de taxa quando total é zero', () {
      const summaryEmpty = StatsSummary(totalPassages: 0, overSpeedPassages: 0);
      expect(summaryEmpty.adherenceRatePercent, equals(100.0));
      expect(summaryEmpty.compliantPassages, equals(0));
      expect(summaryEmpty.totalTollCost, equals(0.0));
      expect(summaryEmpty.props, equals([0, 0, 0.0]));

      const summaryPartial = StatsSummary(totalPassages: 10, overSpeedPassages: 2, totalTollCost: 12.50);
      expect(summaryPartial.compliantPassages, equals(8));
      expect(summaryPartial.adherenceRatePercent, equals(80.0));
      expect(summaryPartial.totalTollCost, equals(12.50));
    });
  });
}
