import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/dashboard/screens/dashboard_screen.dart';
import 'package:sentinela/features/stats/bloc/stats_cubit.dart';

class MockPoiRepository extends Mock implements PoiRepository {}
class MockAlertMachine extends Mock implements AlertMachine {}
class MockPoiSyncService extends Mock implements PoiSyncService {}
class MockStatsCubit extends MockCubit<StatsState> implements StatsCubit {}

void main() {
  late MockPoiRepository mockRepo;
  late MockAlertMachine mockAlertMachine;
  late MockPoiSyncService mockSyncService;
  late DashboardCubit dashboardCubit;

  setUpAll(() {
    registerFallbackValue(VehiclePosition(
      latitude: 0,
      longitude: 0,
      speedKmh: 0,
      bearing: 0,
      accuracyMeters: 5,
      timestamp: DateTime(2026, 1, 1),
    ));
    registerFallbackValue(<PoiPoint>[]);
  });

  setUp(() {
    mockRepo = MockPoiRepository();
    mockAlertMachine = MockAlertMachine();
    mockSyncService = MockPoiSyncService();

    when(() => mockAlertMachine.state).thenReturn(const AlertState(status: AlertStatus.idle));
    when(() => mockSyncService.progressStream).thenAnswer((_) => const Stream.empty());

    dashboardCubit = DashboardCubit(
      repository: mockRepo,
      alertMachine: mockAlertMachine,
    );
  });

  tearDown(() {
    dashboardCubit.close();
  });

  group('DashboardScreen Widget (Dark HUD / M3)', () {
    testWidgets('deve renderizar AppBar Sentinela, velocímetro, sonar e banner de alerta', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: dashboardCubit,
            child: DashboardScreen(syncService: mockSyncService),
          ),
        ),
      );

      expect(find.text('SENTINELA'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_speedometer')), findsOneWidget);
      expect(find.byKey(const Key('dashboard_sonar')), findsOneWidget);
      expect(find.byKey(const Key('dashboard_alert_banner')), findsOneWidget);
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    });

    testWidgets('deve atualizar visual quando o Cubit emitir novo estado com excesso de velocidade', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: dashboardCubit,
            child: DashboardScreen(syncService: mockSyncService),
          ),
        ),
      );

      const candidatePoi = PoiPoint(
        id: 10,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.fixedRadar,
        speedLimit: 60,
        roadName: 'Av. 23 de Maio',
      );

      const activeAlert = ActiveAlert(
        poi: candidatePoi,
        distanceMeters: 250,
        currentSpeedKmh: 82,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 0,
        relativeBearing: 0,
      );

      when(() => mockRepo.findNearbyPois(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        radiusMeters: any(named: 'radiusMeters'),
      )).thenAnswer((_) async => [candidatePoi]);

      when(() => mockAlertMachine.updatePosition(any(), any())).thenReturn(null);
      when(() => mockAlertMachine.state).thenReturn(const AlertState(
        status: AlertStatus.overSpeed,
        activeAlert: activeAlert,
      ));

      await dashboardCubit.onLocationUpdated(VehiclePosition(
        latitude: -23.555,
        longitude: -46.63,
        speedKmh: 82,
        bearing: 0,
        accuracyMeters: 5,
        timestamp: DateTime(2026, 10, 30, 10, 0),
      ));

      await tester.pump();

      expect(find.text('82'), findsOneWidget);
      expect(find.text('Av. 23 de Maio'), findsWidgets);
      expect(find.text('REDUZA A VELOCIDADE'), findsOneWidget);
    });

    testWidgets('deve navegar para a tela de configurações ao tocar no botão de engrenagem', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: dashboardCubit,
            child: DashboardScreen(syncService: mockSyncService),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Configurações & Dados'), findsOneWidget);
      expect(find.text('Filtros de Alerta'), findsOneWidget);
    });

    testWidgets('deve renderizar layout landscape quando a orientação da tela for horizontal', (tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(800, 400));
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: dashboardCubit,
            child: DashboardScreen(syncService: mockSyncService),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard_speedometer')), findsOneWidget);
      expect(find.byKey(const Key('dashboard_sonar')), findsOneWidget);
    });

    testWidgets('deve navegar para a tela de estatísticas ao tocar no botão de analytics', (tester) async {
      final mockStats = MockStatsCubit();
      when(() => mockStats.state).thenReturn(const StatsState());

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: dashboardCubit,
            child: DashboardScreen(
              syncService: mockSyncService,
              statsCubit: mockStats,
            ),
          ),
        ),
      );

      final analyticsButton = find.byIcon(Icons.analytics_rounded);
      expect(analyticsButton, findsOneWidget);
      await tester.tap(analyticsButton);
      await tester.pumpAndSettle();

      expect(find.text('Estatísticas de Condução'), findsOneWidget);
    });
  });
}
