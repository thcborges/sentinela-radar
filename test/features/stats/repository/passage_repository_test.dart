import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/features/stats/models/passage_record.dart';
import 'package:sentinela/features/stats/repository/passage_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database rawDb;
  late PassageRepository repository;

  setUp(() {
    rawDb = sqlite3.openInMemory();
    repository = PassageRepository(rawDb);
    repository.initSchema();
  });

  tearDown(() {
    rawDb.close();
  });

  group('PassageRepository (Histórico Local e Estatísticas 100% Privadas)', () {
    test('deve inicializar tabela de passagens vazia', () async {
      final passages = await repository.getRecentPassages();
      expect(passages, isEmpty);

      final summary = await repository.getStatsSummary();
      expect(summary.totalPassages, equals(0));
      expect(summary.overSpeedPassages, equals(0));
      expect(summary.adherenceRatePercent, equals(100.0));
    });

    test('deve registrar passagem e recuperar na listagem de recentes', () async {
      final now = DateTime(2026, 10, 30, 10, 0);
      final record = PassageRecord(
        poiId: 101,
        poiType: PoiType.fixedRadar,
        vehicleSpeedKmh: 58.5,
        speedLimit: 60,
        timestamp: now,
        isOverSpeed: false,
        roadName: 'Av. Paulista',
      );

      final id = await repository.insertPassage(record);
      expect(id, isPositive);

      final passages = await repository.getRecentPassages();
      expect(passages.length, equals(1));
      expect(passages.first.poiId, equals(101));
      expect(passages.first.poiType, equals(PoiType.fixedRadar));
      expect(passages.first.vehicleSpeedKmh, equals(58.5));
      expect(passages.first.speedLimit, equals(60));
      expect(passages.first.isOverSpeed, isFalse);
      expect(passages.first.roadName, equals('Av. Paulista'));
      expect(passages.first.timestamp, equals(now));
    });

    test('deve calcular taxa de conformidade e contagem de excessos corretamente', () async {
      final now = DateTime.now();

      // 3 passagens dentro do limite
      for (int i = 0; i < 3; i++) {
        await repository.insertPassage(PassageRecord(
          poiId: i,
          poiType: PoiType.fixedRadar,
          vehicleSpeedKmh: 50.0,
          speedLimit: 60,
          timestamp: now.add(Duration(minutes: i)),
          isOverSpeed: false,
          roadName: 'Via Anchieta',
        ));
      }

      // 1 passagem acima do limite
      await repository.insertPassage(PassageRecord(
        poiId: 99,
        poiType: PoiType.fixedRadar,
        vehicleSpeedKmh: 75.0,
        speedLimit: 60,
        timestamp: now.add(const Duration(minutes: 5)),
        isOverSpeed: true,
        roadName: 'Via Anchieta',
      ));

      final summary = await repository.getStatsSummary();
      expect(summary.totalPassages, equals(4));
      expect(summary.overSpeedPassages, equals(1));
      expect(summary.compliantPassages, equals(3));
      // 3 / 4 = 75%
      expect(summary.adherenceRatePercent, equals(75.0));
      expect(summary.totalTollCost, equals(0.0));
    });

    test('deve persistir tarifas de pedágio e acumular totalTollCost no resumo', () async {
      final now = DateTime.now();

      await repository.insertPassage(PassageRecord(
        poiId: 201,
        poiType: PoiType.freeFlowToll,
        vehicleSpeedKmh: 85.0,
        timestamp: now,
        isOverSpeed: false,
        roadName: 'SP-099 Free Flow',
        tollFee: 4.20,
      ));

      await repository.insertPassage(PassageRecord(
        poiId: 202,
        poiType: PoiType.tollBooth,
        vehicleSpeedKmh: 40.0,
        timestamp: now.add(const Duration(minutes: 10)),
        isOverSpeed: false,
        roadName: 'Praça Convencional',
        tollFee: 8.50,
      ));

      final passages = await repository.getRecentPassages();
      expect(passages.length, equals(2));
      expect(passages.first.tollFee, equals(8.50));
      expect(passages.last.tollFee, equals(4.20));

      final summary = await repository.getStatsSummary();
      expect(summary.totalPassages, equals(2));
      expect(summary.totalTollCost, closeTo(12.70, 0.01));
    });

    test('deve limpar histórico completo de passagens com sucesso', () async {
      await repository.insertPassage(PassageRecord(
        poiId: 1,
        poiType: PoiType.fixedRadar,
        vehicleSpeedKmh: 50.0,
        speedLimit: 60,
        timestamp: DateTime.now(),
        isOverSpeed: false,
        roadName: 'Rua da Consolação',
      ));

      expect((await repository.getRecentPassages()).length, equals(1));

      await repository.clearHistory();

      expect((await repository.getRecentPassages()), isEmpty);
      final summary = await repository.getStatsSummary();
      expect(summary.totalPassages, equals(0));
    });
  });
}
