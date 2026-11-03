import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/domain/sync/dataset_update_checker.dart';
import 'package:sentinela/infrastructure/repositories/poi_repository.dart';
import 'package:sentinela/domain/cubits/dashboard_cubit.dart';

class MockPoiRepository extends Mock implements PoiRepository {}
class MockAlertMachine extends Mock implements AlertMachine {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPoiRepository mockRepo;
  late MockAlertMachine mockAlertMachine;

  setUp(() {
    mockRepo = MockPoiRepository();
    mockAlertMachine = MockAlertMachine();
    when(() => mockAlertMachine.state).thenReturn(const AlertState(status: AlertStatus.idle));
    when(() => mockAlertMachine.preferences).thenReturn(const AlertPreferences());
  });

  group('DashboardCubit Dataset Update & Clean Install Detection', () {
    test('quando banco estiver vazio (clean install), emite isDatabaseEmpty = true e isUpdateAvailable = false', () async {
      when(() => mockRepo.getTotalCount()).thenAnswer((_) async => 0);
      when(() => mockRepo.getCountByType()).thenAnswer((_) async => {'radares': 0});
      when(() => mockRepo.getMetadata('last_updated')).thenAnswer((_) async => null);

      final cubit = DashboardCubit(
        repository: mockRepo,
        alertMachine: mockAlertMachine,
      );

      await cubit.loadInitialPoiStats();

      expect(cubit.state.totalPoisCount, 0);
      expect(cubit.state.isDatabaseEmpty, isTrue);
      expect(cubit.state.isUpdateAvailable, isFalse);

      cubit.close();
    });

    test('quando banco tiver POIs mas última sincronização for anterior à esteira, emite isUpdateAvailable = true', () async {
      when(() => mockRepo.getTotalCount()).thenAnswer((_) async => 1997);
      when(() => mockRepo.getCountByType()).thenAnswer((_) async => {'radares': 1997});
      // Data anterior (ex: 2 semanas atrás)
      final oldDate = DateTime.now().toUtc().subtract(const Duration(days: 14));
      when(() => mockRepo.getMetadata('last_updated')).thenAnswer((_) async => oldDate.toIso8601String());

      final cubit = DashboardCubit(
        repository: mockRepo,
        alertMachine: mockAlertMachine,
        datasetUpdateChecker: const DatasetUpdateChecker(
          scheduledWeekday: DateTime.sunday,
          scheduledHourUtc: 3,
          waitMarginHours: 2,
        ),
      );

      await cubit.loadInitialPoiStats();

      expect(cubit.state.totalPoisCount, 1997);
      expect(cubit.state.isDatabaseEmpty, isFalse);
      expect(cubit.state.isUpdateAvailable, isTrue);
      expect(cubit.state.lastDatabaseUpdate, isNotNull);

      cubit.close();
    });

    test('quando banco tiver POIs e estiver atualizado após a esteira mais recente, emite isUpdateAvailable = false', () async {
      when(() => mockRepo.getTotalCount()).thenAnswer((_) async => 1997);
      when(() => mockRepo.getCountByType()).thenAnswer((_) async => {'radares': 1997});
      // Data recente (agora mesmo)
      final recentDate = DateTime.now().toUtc().add(const Duration(minutes: 5));
      when(() => mockRepo.getMetadata('last_updated')).thenAnswer((_) async => recentDate.toIso8601String());

      final cubit = DashboardCubit(
        repository: mockRepo,
        alertMachine: mockAlertMachine,
        datasetUpdateChecker: const DatasetUpdateChecker(
          scheduledWeekday: DateTime.sunday,
          scheduledHourUtc: 3,
          waitMarginHours: 2,
        ),
      );

      await cubit.loadInitialPoiStats();

      expect(cubit.state.totalPoisCount, 1997);
      expect(cubit.state.isDatabaseEmpty, isFalse);
      expect(cubit.state.isUpdateAvailable, isFalse);

      cubit.close();
    });

    test('refreshDatabaseStatus reavalia o status da base de dados', () async {
      when(() => mockRepo.getTotalCount()).thenAnswer((_) async => 0);
      when(() => mockRepo.getCountByType()).thenAnswer((_) async => {'radares': 0});
      when(() => mockRepo.getMetadata('last_updated')).thenAnswer((_) async => null);

      final cubit = DashboardCubit(
        repository: mockRepo,
        alertMachine: mockAlertMachine,
      );

      await cubit.loadInitialPoiStats();
      expect(cubit.state.isDatabaseEmpty, isTrue);

      // Simula sincronização concluída com sucesso
      when(() => mockRepo.getTotalCount()).thenAnswer((_) async => 1997);
      when(() => mockRepo.getCountByType()).thenAnswer((_) async => {'radares': 1997});
      when(() => mockRepo.getMetadata('last_updated')).thenAnswer((_) async => DateTime.now().toIso8601String());

      await cubit.refreshDatabaseStatus();

      expect(cubit.state.totalPoisCount, 1997);
      expect(cubit.state.isDatabaseEmpty, isFalse);
      expect(cubit.state.isUpdateAvailable, isFalse);

      cubit.close();
    });
  });
}
