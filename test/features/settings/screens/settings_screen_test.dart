import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/backup/backup_restore_service.dart';
import 'package:sentinela/core/geo/solar_calculator.dart';
import 'package:sentinela/core/hardware/wakelock_manager.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/models/vehicle_profile.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/overlay/services/overlay_service.dart';
import 'package:sentinela/features/settings/screens/settings_screen.dart';

class MockPoiSyncService extends Mock implements PoiSyncService {}
class MockDashboardCubit extends Mock implements DashboardCubit {}
class MockOverlayService extends Mock implements OverlayService {}
class MockWakelockManager extends Mock implements WakelockManager {}
class MockBackupRestoreService extends Mock implements BackupRestoreService {}

void main() {
  late MockPoiSyncService mockSyncService;
  late StreamController<SyncProgress> syncStreamController;

  setUpAll(() {
    registerFallbackValue(PoiType.fixedRadar);
    registerFallbackValue(VehicleProfile.car());
    registerFallbackValue(HudThemeMode.darkOnly);
  });

  setUp(() {
    mockSyncService = MockPoiSyncService();
    syncStreamController = StreamController<SyncProgress>.broadcast();
    when(() => mockSyncService.progressStream)
        .thenAnswer((_) => syncStreamController.stream);
  });

  tearDown(() {
    syncStreamController.close();
  });

  group('SettingsScreen Widget (Material Design 3)', () {
    testWidgets('deve renderizar seções de atualização, filtros e áudio', (tester) async {
      when(() => mockSyncService.startInAppUpdate()).thenAnswer((_) async => true);

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: SettingsScreen(
            syncService: mockSyncService,
            initialStats: const {
              'radares': 24810,
              'semaforos': 7940,
              'lombadas': 34200,
              'pedagios': 830,
            },
            lastUpdatedText: '29/10/2026 às 15:30',
          ),
        ),
      );

      expect(find.text('Configurações & Dados'), findsOneWidget);
      expect(find.text('Atualização da Base de POIs'), findsOneWidget);
      expect(find.text('Filtros de Alerta'), findsOneWidget);
      expect(find.text('24810'), findsOneWidget);
      expect(find.text('ATUALIZAR BASE AGORA (VIA WI-FI)'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Preferências de Áudio'), 200);
      expect(find.text('Preferências de Áudio'), findsOneWidget);
    });

    testWidgets('deve disparar startInAppUpdate ao tocar no botão de atualização', (tester) async {
      when(() => mockSyncService.startInAppUpdate(requireWifi: any(named: 'requireWifi')))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: SettingsScreen(
            syncService: mockSyncService,
            initialStats: const {'radares': 100},
          ),
        ),
      );

      await tester.tap(find.text('ATUALIZAR BASE AGORA (VIA WI-FI)'));
      await tester.pump();

      verify(() => mockSyncService.startInAppUpdate(requireWifi: any(named: 'requireWifi'))).called(1);
    });

    testWidgets('deve exibir mensagem de progresso durante a sincronização', (tester) async {
      when(() => mockSyncService.startInAppUpdate()).thenAnswer((_) async => true);

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: SettingsScreen(
            syncService: mockSyncService,
          ),
        ),
      );

      syncStreamController.add(const SyncProgress(
        status: SyncStatus.downloading,
        message: 'Baixando dados abertos do Brasil...',
        progress: 0.35,
      ));

      await tester.pump();

      expect(find.text('Baixando dados abertos do Brasil...'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('deve alterar switches de filtros e notificar DashboardCubit', (tester) async {
      final mockDashboardCubit = MockDashboardCubit();
      when(() => mockDashboardCubit.state).thenReturn(const DashboardState());
      when(() => mockSyncService.startInAppUpdate()).thenAnswer((_) async => true);

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: SettingsScreen(
            syncService: mockSyncService,
            dashboardCubit: mockDashboardCubit,
          ),
        ),
      );

      final radarSwitch = find.widgetWithText(SwitchListTile, 'Radares de Velocidade');
      expect(radarSwitch, findsOneWidget);
      await tester.tap(radarSwitch);
      await tester.pump();

      await tester.scrollUntilVisible(find.widgetWithText(SwitchListTile, 'Semáforos e Câmeras'), 200);
      final tlSwitch = find.widgetWithText(SwitchListTile, 'Semáforos e Câmeras');
      await tester.tap(tlSwitch);
      await tester.pump();

      await tester.scrollUntilVisible(find.widgetWithText(SwitchListTile, 'Lombadas e Quebra-Molas'), 200);
      final bumpSwitch = find.widgetWithText(SwitchListTile, 'Lombadas e Quebra-Molas');
      await tester.tap(bumpSwitch);
      await tester.pump();

      await tester.scrollUntilVisible(find.widgetWithText(SwitchListTile, 'Praças de Pedágio'), 200);
      final tollSwitch = find.widgetWithText(SwitchListTile, 'Praças de Pedágio');
      await tester.tap(tollSwitch);
      await tester.pump();

      await tester.scrollUntilVisible(find.widgetWithText(SwitchListTile, 'Polícia Rodoviária'), 200);
      final patrolSwitch = find.widgetWithText(SwitchListTile, 'Polícia Rodoviária');
      await tester.tap(patrolSwitch);
      await tester.pump();

      verify(() => mockDashboardCubit.togglePoiType(any(), false)).called(9);

      await tester.scrollUntilVisible(find.widgetWithText(SwitchListTile, 'Avisos por Voz (TTS Offline)'), 300);
      final voiceSwitch = find.widgetWithText(SwitchListTile, 'Avisos por Voz (TTS Offline)');
      await tester.tap(voiceSwitch);
      await tester.pump();

      final beepSwitch = find.widgetWithText(SwitchListTile, 'Bipes de Proximidade (Sonar)');
      await tester.tap(beepSwitch);
      await tester.pump();
    });

    testWidgets('deve exibir mensagem de erro quando status de sincronização falhar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: SettingsScreen(
            syncService: mockSyncService,
          ),
        ),
      );

      syncStreamController.add(const SyncProgress(
        status: SyncStatus.error,
        message: 'Erro na conexão HTTP 500',
        progress: 0.0,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Erro na conexão HTTP 500'), findsOneWidget);
    });
    testWidgets('deve acionar OverlayService ao alternar switch de Janela Flutuante', (tester) async {
      final mockOverlay = MockOverlayService();
      when(() => mockOverlay.isOverlayOpen).thenReturn(false);
      when(() => mockOverlay.startOverlay()).thenAnswer((_) async => true);
      when(() => mockOverlay.stopOverlay()).thenAnswer((_) async => true);

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: SettingsScreen(
            syncService: mockSyncService,
            overlayService: mockOverlay,
          ),
        ),
      );

      await tester.scrollUntilVisible(find.text('Janela Flutuante (Overlay)'), 300);
      expect(find.text('Janela Flutuante (Overlay)'), findsOneWidget);

      await tester.tap(find.text('Janela Flutuante (Overlay)'));
      await tester.pump();

      verify(() => mockOverlay.startOverlay()).called(1);
    });

    testWidgets('deve disparar startInAppUpdate com requireWifi respeitando switch de Wi-Fi', (tester) async {
      when(() => mockSyncService.startInAppUpdate(requireWifi: any(named: 'requireWifi')))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: SettingsScreen(
            syncService: mockSyncService,
          ),
        ),
      );

      expect(find.text('Apenas sincronizar via Wi-Fi'), findsOneWidget);

      final updateBtn = find.text('ATUALIZAR BASE AGORA (VIA WI-FI)');
      await tester.tap(updateBtn);
      await tester.pump();

      verify(() => mockSyncService.startInAppUpdate(requireWifi: true)).called(1);

      // Alternar switch de Wi-Fi para false
      await tester.tap(find.text('Apenas sincronizar via Wi-Fi'));
      await tester.pump();

      await tester.tap(updateBtn);
      await tester.pump();

      verify(() => mockSyncService.startInAppUpdate(requireWifi: false)).called(1);
    });

    testWidgets('deve acionar WakelockManager ao alternar switch de manter tela ativa', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockWakelock = MockWakelockManager();
      when(() => mockWakelock.enable()).thenAnswer((_) async {});
      when(() => mockWakelock.disable()).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: SettingsScreen(
            syncService: mockSyncService,
            wakelockManager: mockWakelock,
          ),
        ),
      );

      await tester.scrollUntilVisible(find.text('Manter Tela Ativa (Wakelock)'), 300);
      expect(find.text('Manter Tela Ativa (Wakelock)'), findsOneWidget);

      // Desativa wakelock
      await tester.tap(find.text('Manter Tela Ativa (Wakelock)'), warnIfMissed: false);
      await tester.pump();
      verify(() => mockWakelock.disable()).called(1);

      // Reativa wakelock
      await tester.tap(find.text('Manter Tela Ativa (Wakelock)'), warnIfMissed: false);
      await tester.pump();
      verify(() => mockWakelock.enable()).called(1);
    });

    testWidgets('deve exportar backup e exibir SnackBar ao tocar no botão de exportar', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockBackup = MockBackupRestoreService();
      when(() => mockBackup.exportBackupToJson(preferences: any(named: 'preferences')))
          .thenAnswer((_) async => '{"version": 1}');

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: SettingsScreen(
            syncService: mockSyncService,
            backupService: mockBackup,
          ),
        ),
      );

      await tester.scrollUntilVisible(find.byKey(const Key('settings_export_backup_button')), 300);
      expect(find.byKey(const Key('settings_export_backup_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings_export_backup_button')), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Backup gerado com sucesso!'), findsOneWidget);
      verify(() => mockBackup.exportBackupToJson(preferences: any(named: 'preferences'))).called(1);
    });

    testWidgets('deve alterar preferências de tolerância e alertOnlyIfOverSpeed', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
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
          ),
        ),
      );

      await tester.scrollUntilVisible(find.byKey(const Key('settings_alert_only_overspeed_switch')), 300);
      expect(find.byKey(const Key('settings_alert_only_overspeed_switch')), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings_alert_only_overspeed_switch')), warnIfMissed: false);
      await tester.pump();
    });

    testWidgets('deve alterar perfil veicular e tema do HUD nos SegmentedButtons', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockCubit = MockDashboardCubit();
      when(() => mockCubit.state).thenReturn(const DashboardState());
      when(() => mockCubit.setVehicleProfile(any())).thenReturn(null);
      when(() => mockCubit.setHudThemeMode(any())).thenReturn(null);

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: SettingsScreen(
            syncService: mockSyncService,
            dashboardCubit: mockCubit,
          ),
        ),
      );

      await tester.scrollUntilVisible(find.byKey(const Key('settings_vehicle_profile_segmented')), 300);
      expect(find.byKey(const Key('settings_vehicle_profile_segmented')), findsOneWidget);

      // Toca em 'Pesado'
      await tester.tap(find.text('Pesado'), warnIfMissed: false);
      await tester.pump();
      verify(() => mockCubit.setVehicleProfile(any())).called(1);

      await tester.scrollUntilVisible(find.byKey(const Key('settings_hud_theme_segmented')), 300);
      expect(find.byKey(const Key('settings_hud_theme_segmented')), findsOneWidget);

      // Toca em 'Automático'
      await tester.tap(find.text('Automático'), warnIfMissed: false);
      await tester.pump();
      verify(() => mockCubit.setHudThemeMode(HudThemeMode.solarAutomatic)).called(1);
    });
  });
}
