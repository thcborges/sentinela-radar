import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/dashboard/screens/dashboard_screen.dart';

class MockPoiRepository extends Mock implements PoiRepository {}
class MockAlertMachine extends Mock implements AlertMachine {}
class MockPoiSyncService extends Mock implements PoiSyncService {}
class MockDashboardCubit extends MockCubit<DashboardState> implements DashboardCubit {}

void main() {
  late MockPoiSyncService mockSyncService;
  late MockDashboardCubit mockCubit;
  late StreamController<SyncProgress> syncProgressController;

  setUp(() {
    mockSyncService = MockPoiSyncService();
    mockCubit = MockDashboardCubit();
    syncProgressController = StreamController<SyncProgress>.broadcast();

    when(() => mockSyncService.progressStream).thenAnswer((_) => syncProgressController.stream);
    when(() => mockSyncService.startInAppUpdate(requireWifi: any(named: 'requireWifi'))).thenAnswer((_) async => true);
    when(() => mockCubit.refreshDatabaseStatus()).thenAnswer((_) async {});
    when(() => mockCubit.alertMachine).thenReturn(AlertMachine());
  });

  tearDown(() {
    syncProgressController.close();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      theme: SentinelaTheme.darkTheme,
      home: BlocProvider<DashboardCubit>.value(
        value: mockCubit,
        child: DashboardScreen(
          syncService: mockSyncService,
        ),
      ),
    );
  }

  group('DashboardScreen Clean Install & Update Banners', () {
    testWidgets('exibe aviso de clean install quando isDatabaseEmpty for true', (tester) async {
      when(() => mockCubit.state).thenReturn(const DashboardState(
        isDatabaseEmpty: true,
        isUpdateAvailable: false,
        totalPoisCount: 0,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('dashboard_clean_install_banner')), findsOneWidget);
      expect(find.text('Base de Radares Não Instalada'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_download_clean_db_button')), findsOneWidget);

      // Tocar no botão deve disparar download in-app
      await tester.tap(find.byKey(const Key('dashboard_download_clean_db_button')));
      await tester.pump();

      verify(() => mockSyncService.startInAppUpdate(requireWifi: false)).called(1);
    });

    testWidgets('exibe alerta de atualização semanal quando isUpdateAvailable for true e isDatabaseEmpty for false', (tester) async {
      when(() => mockCubit.state).thenReturn(const DashboardState(
        isDatabaseEmpty: false,
        isUpdateAvailable: true,
        totalPoisCount: 1997,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('dashboard_update_available_banner')), findsOneWidget);
      expect(find.text('Atualização Semanal Disponível'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_update_db_button')), findsOneWidget);

      // Tocar no botão deve disparar atualização
      await tester.tap(find.byKey(const Key('dashboard_update_db_button')));
      await tester.pump();

      verify(() => mockSyncService.startInAppUpdate(requireWifi: false)).called(1);
    });

    testWidgets('não exibe nenhum banner quando base estiver preenchida e atualizada', (tester) async {
      when(() => mockCubit.state).thenReturn(const DashboardState(
        isDatabaseEmpty: false,
        isUpdateAvailable: false,
        totalPoisCount: 1997,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byKey(const Key('dashboard_clean_install_banner')), findsNothing);
      expect(find.byKey(const Key('dashboard_update_available_banner')), findsNothing);
    });

    testWidgets('ao receber SyncStatus.success pelo stream, invoca refreshDatabaseStatus no cubit', (tester) async {
      when(() => mockCubit.state).thenReturn(const DashboardState(
        isDatabaseEmpty: true,
        isUpdateAvailable: false,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      syncProgressController.add(const SyncProgress(
        status: SyncStatus.success,
        message: 'Base atualizada com sucesso',
        progress: 1.0,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => mockCubit.refreshDatabaseStatus()).called(1);
    });
  });
}
