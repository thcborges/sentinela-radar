import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/features/stats/bloc/stats_cubit.dart';
import 'package:sentinela/features/stats/models/passage_record.dart';
import 'package:sentinela/features/stats/repository/passage_repository.dart';

class MockPassageRepository extends Mock implements PassageRepository {}

void main() {
  late MockPassageRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(PassageRecord(
      poiId: 0,
      poiType: PoiType.fixedRadar,
      vehicleSpeedKmh: 0,
      timestamp: DateTime(2026, 1, 1),
      isOverSpeed: false,
    ));
  });

  setUp(() {
    mockRepo = MockPassageRepository();
  });

  group('StatsCubit (Gerenciamento Reativo de Estatísticas Privadas)', () {
    const summaryInitial = StatsSummary(totalPassages: 2, overSpeedPassages: 0);
    final passageSample = PassageRecord(
      id: 1,
      poiId: 10,
      poiType: PoiType.fixedRadar,
      vehicleSpeedKmh: 55.0,
      speedLimit: 60,
      timestamp: DateTime(2026, 10, 30),
      isOverSpeed: false,
      roadName: 'Av. Brasil',
    );

    blocTest<StatsCubit, StatsState>(
      'deve carregar estatísticas e lista de passagens recentes com sucesso',
      build: () {
        when(() => mockRepo.getStatsSummary()).thenAnswer((_) async => summaryInitial);
        when(() => mockRepo.getRecentPassages(limit: any(named: 'limit')))
            .thenAnswer((_) async => [passageSample]);
        return StatsCubit(repository: mockRepo);
      },
      act: (cubit) => cubit.loadStats(),
      expect: () => [
        const StatsState(isLoading: true),
        StatsState(
          isLoading: false,
          summary: summaryInitial,
          recentPassages: [passageSample],
        ),
      ],
      verify: (_) {
        verify(() => mockRepo.getStatsSummary()).called(1);
        verify(() => mockRepo.getRecentPassages(limit: 20)).called(1);
      },
    );

    blocTest<StatsCubit, StatsState>(
      'deve registrar nova passagem e atualizar estatísticas',
      build: () {
        when(() => mockRepo.insertPassage(any())).thenAnswer((_) async => 1);
        when(() => mockRepo.getStatsSummary()).thenAnswer((_) async => summaryInitial);
        when(() => mockRepo.getRecentPassages(limit: any(named: 'limit')))
            .thenAnswer((_) async => [passageSample]);
        return StatsCubit(repository: mockRepo);
      },
      act: (cubit) => cubit.recordPassage(passageSample),
      expect: () => [
        StatsState(
          isLoading: false,
          summary: summaryInitial,
          recentPassages: [passageSample],
        ),
      ],
      verify: (_) {
        verify(() => mockRepo.insertPassage(passageSample)).called(1);
      },
    );

    blocTest<StatsCubit, StatsState>(
      'deve limpar histórico e redefinir estado',
      build: () {
        when(() => mockRepo.clearHistory()).thenAnswer((_) async {});
        return StatsCubit(repository: mockRepo);
      },
      act: (cubit) => cubit.clearHistory(),
      expect: () => [
        const StatsState(
          isLoading: false,
          summary: StatsSummary(totalPassages: 0, overSpeedPassages: 0),
          recentPassages: [],
        ),
      ],
      verify: (_) {
        verify(() => mockRepo.clearHistory()).called(1);
      },
    );
  });
}
