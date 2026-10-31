import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/diagnostics/system_diagnostics.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/core/engine/poi_cluster_engine.dart';
import 'package:sentinela/core/engine/section_control_machine.dart';
import 'package:sentinela/core/geo/dead_reckoning_engine.dart';
import 'package:sentinela/core/hardware/wakelock_manager.dart';
import 'package:sentinela/core/location/location_service_interface.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/data/repository/custom_poi_repository.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/dashboard/screens/dashboard_screen.dart';
import 'package:sentinela/features/stats/bloc/stats_cubit.dart';
import 'package:sqlite3/sqlite3.dart';

class MockPoiRepository extends Mock implements PoiRepository {}
class MockAlertMachine extends Mock implements AlertMachine {}
class MockPoiSyncService extends Mock implements PoiSyncService {}
class MockStatsCubit extends MockCubit<StatsState> implements StatsCubit {}
class MockWakelockManager extends Mock implements WakelockManager {}
class MockLocationService extends Mock implements LocationService {}
class MockSystemDiagnosticsService extends Mock implements SystemDiagnosticsService {}
class MockDashboardCubit extends MockCubit<DashboardState> implements DashboardCubit {}

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
    when(() => mockAlertMachine.preferences).thenReturn(const AlertPreferences());
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

    testWidgets('deve habilitar Wakelock no initState e desabilitar no dispose', (tester) async {
      final mockWakelock = MockWakelockManager();
      when(() => mockWakelock.enable()).thenAnswer((_) async {});
      when(() => mockWakelock.disable()).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: dashboardCubit,
            child: DashboardScreen(
              syncService: mockSyncService,
              wakelockManager: mockWakelock,
            ),
          ),
        ),
      );

      verify(() => mockWakelock.enable()).called(1);

      // Desmonta widget para acionar dispose
      await tester.pumpWidget(const SizedBox.shrink());
      verify(() => mockWakelock.disable()).called(1);
    });

    testWidgets('deve assinar stream do LocationService e atualizar DashboardCubit', (tester) async {
      when(() => mockRepo.findNearbyPois(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          )).thenAnswer((_) async => []);

      final mockLocation = MockLocationService();
      final streamController = StreamController<VehiclePosition>.broadcast();
      when(() => mockLocation.getPositionStream(
            distanceFilterMeters: any(named: 'distanceFilterMeters'),
            intervalMs: any(named: 'intervalMs'),
          )).thenAnswer((_) => streamController.stream);

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: dashboardCubit,
            child: DashboardScreen(
              syncService: mockSyncService,
              locationService: mockLocation,
            ),
          ),
        ),
      );

      final pos = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 80.0,
        bearing: 90.0,
        accuracyMeters: 4.0,
        timestamp: DateTime(2026, 10, 30, 10, 0),
      );

      streamController.add(pos);
      await tester.pump();

      expect(dashboardCubit.state.currentSpeedKmh, equals(80.0));
      expect(dashboardCubit.state.currentBearing, equals(90.0));

      await streamController.close();
    });

    testWidgets('deve abrir modal de diagnóstico ao tocar no botão de diagnóstico na AppBar', (tester) async {
      final mockDiagnostics = MockSystemDiagnosticsService();
      when(() => mockDiagnostics.runDiagnostics()).thenAnswer(
        (_) async => const DiagnosticReport(
          isGpsHardwareEnabled: true,
          gpsPermission: LocationPermissionStatus.whileInUse,
          isDatabaseHealthy: true,
          totalPoisIndexed: 70000,
          databaseSizeMb: 15.5,
          isNetworkConnected: true,
          isWifiConnected: true,
          isReadyForNavigation: true,
          summaryMessage: 'Sistema 100% operacional para navegação.',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: dashboardCubit,
            child: DashboardScreen(
              syncService: mockSyncService,
              diagnosticsService: mockDiagnostics,
            ),
          ),
        ),
      );

      final diagButton = find.byKey(const Key('dashboard_diagnostics_button'));
      expect(diagButton, findsOneWidget);

      await tester.tap(diagButton);
      await tester.pumpAndSettle();

      expect(find.text('Sistema 100% operacional para navegação.'), findsOneWidget);
      expect(find.text('GPS Hardware'), findsOneWidget);
      expect(find.text('70000 POIs indexados'), findsOneWidget);
      expect(find.text('Wi-Fi'), findsOneWidget);
    });

    testWidgets('deve exibir status de diagnóstico offline e erro de integridade', (tester) async {
      final mockDiagnostics = MockSystemDiagnosticsService();
      when(() => mockDiagnostics.runDiagnostics()).thenAnswer(
        (_) async => const DiagnosticReport(
          isGpsHardwareEnabled: false,
          gpsPermission: LocationPermissionStatus.always,
          isDatabaseHealthy: false,
          totalPoisIndexed: 0,
          databaseSizeMb: 0.0,
          isNetworkConnected: false,
          isWifiConnected: false,
          isReadyForNavigation: false,
          summaryMessage: 'Chip de GPS desativado.',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: dashboardCubit,
            child: DashboardScreen(
              syncService: mockSyncService,
              diagnosticsService: mockDiagnostics,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('dashboard_diagnostics_button')));
      await tester.pumpAndSettle();

      expect(find.text('Desativado'), findsOneWidget);
      expect(find.text('Offline (OK)'), findsOneWidget);
      expect(find.text('Erro de integridade'), findsOneWidget);
    });

    testWidgets('deve renderizar layout portrait quando a orientação da tela for vertical', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
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

      expect(find.text('SENTINELA'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_speedometer')), findsOneWidget);
      expect(find.byKey(const Key('dashboard_sonar')), findsOneWidget);
      expect(find.byKey(const Key('dashboard_alert_banner')), findsOneWidget);
    });

    testWidgets('deve alternar modo espelho HUD ao tocar no botao de espelhamento na AppBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: dashboardCubit,
            child: DashboardScreen(syncService: mockSyncService),
          ),
        ),
      );

      final hudButton = find.byKey(const Key('dashboard_hud_mirror_button'));
      expect(hudButton, findsOneWidget);
      expect(dashboardCubit.state.isHudMirrorMode, isFalse);

      await tester.tap(hudButton);
      await tester.pump();

      expect(dashboardCubit.state.isHudMirrorMode, isTrue);

      await tester.tap(hudButton);
      await tester.pump();

      expect(dashboardCubit.state.isHudMirrorMode, isFalse);
    });

    testWidgets('deve renderizar banner de radar de trecho quando houver trecho ativo', (tester) async {
      final corridor = AverageSpeedCorridor.fromCoordinates(
        id: 'c1',
        name: 'Trecho Via Anchieta',
        speedLimitKmh: 90,
        entryLatitude: -23.55,
        entryLongitude: -46.63,
        entryBearing: 0.0,
        exitLatitude: -23.50,
        exitLongitude: -46.63,
        exitBearing: 0.0,
      );

      final cubit = DashboardCubit(
        repository: mockRepo,
        alertMachine: mockAlertMachine,
      );
      // ignore: invalid_use_of_visible_for_testing_member
      cubit.emit(cubit.state.copyWith(
        sectionControlState: SectionControlState(
          isActive: true,
          corridor: corridor,
          averageSpeedKmh: 95.0,
          isOverSpeed: true,
          coveredDistanceMeters: 500,
          remainingDistanceMeters: 1500,
          elapsedSeconds: 20,
          targetRemainingSeconds: 15,
        ),
      ));

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: cubit,
            child: DashboardScreen(syncService: mockSyncService),
          ),
        ),
      );

      expect(find.byKey(const Key('dashboard_section_control_banner')), findsOneWidget);
      expect(find.text('RADAR DE TRECHO (VEL. MÉDIA)'), findsOneWidget);
      expect(find.text('95.0 km/h / Limite: 90 km/h'), findsOneWidget);
      expect(find.text('1500m rest.'), findsOneWidget);
      expect(find.text('Aguarde 15s'), findsOneWidget);

      await cubit.close();
    });

    testWidgets('deve abrir modal de marcação rápida ao tocar no FAB e registrar ponto', (tester) async {
      final db = sqlite3.openInMemory();
      final customRepo = CustomPoiRepository(db);
      customRepo.initializeSchema();

      final customCubit = DashboardCubit(
        repository: mockRepo,
        alertMachine: mockAlertMachine,
        customPoiRepository: customRepo,
      );

      when(() => mockRepo.findNearbyPois(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        radiusMeters: any(named: 'radiusMeters'),
      )).thenAnswer((_) async => []);

      final testPos = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 60,
        bearing: 90,
        accuracyMeters: 5,
        timestamp: DateTime(2026, 10, 30, 12, 0),
      );
      await customCubit.onLocationUpdated(testPos);

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: customCubit,
            child: DashboardScreen(syncService: mockSyncService),
          ),
        ),
      );

      expect(find.byKey(const Key('dashboard_quick_report_fab')), findsOneWidget);

      await tester.tap(find.byKey(const Key('dashboard_quick_report_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Marcar Ponto na Via'), findsOneWidget);
      expect(find.byKey(const Key('quick_report_mobile_radar')), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick_report_mobile_radar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_report_success_snackbar')), findsOneWidget);
      expect(customCubit.state.userPoiCount, 1);

      await customCubit.close();
      db.close();
    });

    testWidgets('deve exibir badge de túnel / dead reckoning quando ativado', (tester) async {
      final mockCubit = MockDashboardCubit();
      when(() => mockCubit.state).thenReturn(
        const DashboardState(
          isGpsFixValid: true,
          deadReckoningStatus: DeadReckoningStatus.deadReckoning,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: mockCubit,
            child: DashboardScreen(syncService: mockSyncService),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('dashboard_tunnel_badge')), findsOneWidget);
      expect(find.text('TÚNEL / NAVEGAÇÃO INERCIAL'), findsOneWidget);
      await mockCubit.close();
    });

    testWidgets('deve exibir badge de cluster multi-ponto quando houver múltiplos POIs colocalizados', (tester) async {
      final mockCubit = MockDashboardCubit();
      final radar = const PoiPoint(id: 1, type: PoiType.fixedRadar, latitude: -23.55, longitude: -46.63);
      final bump = const PoiPoint(id: 2, type: PoiType.physicalSpeedBump, latitude: -23.5501, longitude: -46.63);
      final cluster = PoiCluster(
        primaryPoi: radar,
        associatedPois: [bump],
        centerLatitude: -23.55,
        centerLongitude: -46.63,
        compositeTtsPhrase: 'Radar e lombada',
      );

      when(() => mockCubit.state).thenReturn(
        DashboardState(
          isGpsFixValid: true,
          activeCluster: cluster,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<DashboardCubit>.value(
            value: mockCubit,
            child: DashboardScreen(syncService: mockSyncService),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('dashboard_cluster_badge')), findsOneWidget);
      expect(find.text('+1 fiscalização colocalizada'), findsOneWidget);
      await mockCubit.close();
    });
  });
}
