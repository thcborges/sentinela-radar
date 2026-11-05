import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/core/l10n/app_language.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/settings/screens/settings_screen.dart';

class MockPoiSyncService extends Mock implements PoiSyncService {}
class MockDashboardCubit extends Mock implements DashboardCubit {}
class MockAlertMachine extends Mock implements AlertMachine {}

void main() {
  late MockPoiSyncService mockSyncService;
  late MockDashboardCubit mockDashboardCubit;
  late MockAlertMachine mockAlertMachine;
  late StreamController<SyncProgress> syncStreamController;

  setUpAll(() {
    registerFallbackValue(PoiType.fixedRadar);
    registerFallbackValue(const AlertPreferences());
    registerFallbackValue(AppLanguage.pt);
  });

  setUp(() {
    mockSyncService = MockPoiSyncService();
    mockDashboardCubit = MockDashboardCubit();
    mockAlertMachine = MockAlertMachine();
    syncStreamController = StreamController<SyncProgress>.broadcast();

    when(() => mockSyncService.progressStream)
        .thenAnswer((_) => syncStreamController.stream);
    when(() => mockDashboardCubit.alertMachine).thenReturn(mockAlertMachine);
    when(() => mockAlertMachine.updatePreferences(any())).thenReturn(null);
    when(() => mockDashboardCubit.state).thenReturn(
      const DashboardState(
        enabledPoiTypes: {
          PoiType.fixedRadar,
          PoiType.mobileRadar,
          PoiType.trafficLightRadar,
          PoiType.redLightCamera,
          PoiType.electronicSpeedBump,
          PoiType.physicalSpeedBump,
          PoiType.tollBooth,
          PoiType.freeFlowToll,
          PoiType.highwayPatrol,
        },
      ),
    );
    when(() => mockDashboardCubit.togglePoiType(any(), any())).thenReturn(null);
    when(() => mockDashboardCubit.setHapticFeedback(
          enabled: any(named: 'enabled'),
          intensity: any(named: 'intensity'),
        )).thenReturn(null);
    when(() => mockDashboardCubit.setLanguage(any())).thenReturn(null);
    when(() => mockDashboardCubit.setHighContrastMode(any())).thenReturn(null);
  });

  tearDown(() {
    syncStreamController.close();
  });

  group('SettingsScreen - Seleção Granular de Pontos de Interesse (POIs)', () {
    testWidgets('deve exibir switches dedicados para todos os tipos de POI solicitados pelo usuário', (tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: SettingsScreen(
            syncService: mockSyncService,
            dashboardCubit: mockDashboardCubit,
          ),
        ),
      );

      // Verifica presença de todos os tipos requeridos
      expect(find.text('Radar Fixo'), findsOneWidget);
      expect(find.text('Radar Móvel'), findsOneWidget);
      expect(find.text('Semáforo com Radar'), findsOneWidget);
      expect(find.text('Câmera de Semáforo (Vermelho)'), findsOneWidget);
      expect(find.text('Praças de Pedágio'), findsOneWidget);
      expect(find.text('Lombadas e Quebra-Molas'), findsOneWidget);
      expect(find.text('Polícia Rodoviária'), findsOneWidget);
    });

    testWidgets('deve sincronizar com dashboardCubit ao alternar categorias individuais', (tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: SettingsScreen(
            syncService: mockSyncService,
            dashboardCubit: mockDashboardCubit,
          ),
        ),
      );

      // Desativa radar móvel
      await tester.tap(find.byKey(const Key('filter_switch_mobile_radar')), warnIfMissed: false);
      await tester.pump();
      verify(() => mockDashboardCubit.togglePoiType(PoiType.mobileRadar, false)).called(1);

      // Desativa câmera de semáforo
      await tester.tap(find.byKey(const Key('filter_switch_red_light_camera')), warnIfMissed: false);
      await tester.pump();
      verify(() => mockDashboardCubit.togglePoiType(PoiType.redLightCamera, false)).called(1);
    });
  });
}
