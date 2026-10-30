import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sentinela/core/backup/backup_restore_service.dart';
import 'package:sentinela/core/diagnostics/system_diagnostics.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/hardware/wakelock_manager.dart';
import 'package:sentinela/core/location/geolocator_location_service.dart';
import 'package:sentinela/core/location/location_service_interface.dart';
import 'package:sentinela/core/network/connectivity_checker.dart';
import 'package:sentinela/core/platform/live_activity_service.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/data/database/seed_database_loader.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/dashboard/screens/dashboard_screen.dart';
import 'package:sentinela/features/overlay/services/overlay_service.dart';
import 'package:sentinela/features/overlay/widgets/floating_overlay_widget.dart';
import 'package:sentinela/features/stats/bloc/stats_cubit.dart';
import 'package:sentinela/features/stats/repository/passage_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SeedDatabaseLoader().ensureDatabaseInstalled(targetPath: 'sentinela_brasil.db');
  runApp(const SentinelaApp());
}

/// Ponto de entrada nativo isolado para renderização do Overlay Flutuante em segundo plano.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SentinelaTheme.darkTheme,
      home: const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: FloatingOverlayWidget(
            currentSpeedKmh: 0.0,
          ),
        ),
      ),
    ),
  );
}

/// Widget raiz da aplicação Sentinela.
class SentinelaApp extends StatefulWidget {
  final bool useInMemoryDb;
  final WakelockManager? wakelockManager;
  final LocationService? locationService;
  final NetworkConnectivityChecker? connectivityChecker;
  final OverlayService? overlayService;
  final Database? database;
  final BackupRestoreService? backupService;
  final LiveActivityService? liveActivityService;

  const SentinelaApp({
    super.key,
    this.useInMemoryDb = false,
    this.wakelockManager,
    this.locationService,
    this.connectivityChecker,
    this.overlayService,
    this.database,
    this.backupService,
    this.liveActivityService,
  });

  @override
  State<SentinelaApp> createState() => _SentinelaAppState();
}

class _SentinelaAppState extends State<SentinelaApp> {
  late Database _rawDb;
  late DatabaseManager _dbManager;
  late PoiRepository _repository;
  late AlertMachine _alertMachine;
  late PoiSyncService _syncService;
  late PassageRepository _passageRepository;
  late StatsCubit _statsCubit;
  late DashboardCubit _dashboardCubit;
  late WakelockManager _wakelockManager;
  late SystemDiagnosticsService _diagnosticsService;
  late BackupRestoreService _backupService;
  late LiveActivityService _liveActivityService;
  LocationService? _locationService;
  OverlayService? _overlayService;

  @override
  void initState() {
    super.initState();
    if (widget.database != null) {
      _rawDb = widget.database!;
      _wakelockManager = widget.wakelockManager ?? PlatformWakelockManager();
      _locationService = widget.locationService;
      _overlayService = widget.overlayService;
    } else if (widget.useInMemoryDb) {
      _rawDb = sqlite3.openInMemory();
      _wakelockManager = widget.wakelockManager ?? PlatformWakelockManager();
      _locationService = widget.locationService;
      _overlayService = widget.overlayService;
    } else {
      _rawDb = sqlite3.open('sentinela_brasil.db');
      _wakelockManager = widget.wakelockManager ?? PlatformWakelockManager();
      _locationService = widget.locationService ?? GeolocatorLocationService();
      _overlayService = widget.overlayService;
    }

    _dbManager = DatabaseManager(_rawDb);
    _dbManager.initializeSchema();

    _repository = PoiRepository(_dbManager);
    _alertMachine = AlertMachine();
    _syncService = PoiSyncService(
      _rawDb,
      connectivityChecker: widget.connectivityChecker ?? PlatformConnectivityChecker(),
    );

    _passageRepository = PassageRepository(_rawDb);
    _passageRepository.initSchema();
    _statsCubit = StatsCubit(repository: _passageRepository);
    _statsCubit.loadStats();

    _backupService = widget.backupService ??
        BackupRestoreService(
          passageRepository: _passageRepository,
          alertMachine: _alertMachine,
        );

    _liveActivityService = widget.liveActivityService ?? LiveActivityService();

    _diagnosticsService = SystemDiagnosticsService(
      locationService: _locationService ?? GeolocatorLocationService(),
      repository: _repository,
      dbManager: _dbManager,
      connectivityChecker: widget.connectivityChecker ?? PlatformConnectivityChecker(),
    );

    _dashboardCubit = DashboardCubit(
      repository: _repository,
      alertMachine: _alertMachine,
      liveActivityService: _liveActivityService,
    );
  }

  @override
  void dispose() {
    _dashboardCubit.close();
    _statsCubit.close();
    _syncService.dispose();
    _rawDb.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentinela Radar',
      debugShowCheckedModeBanner: false,
      theme: SentinelaTheme.darkTheme,
      home: BlocProvider<DashboardCubit>.value(
        value: _dashboardCubit,
        child: DashboardScreen(
          syncService: _syncService,
          statsCubit: _statsCubit,
          wakelockManager: _wakelockManager,
          locationService: _locationService,
          overlayService: _overlayService,
          diagnosticsService: _diagnosticsService,
          backupService: _backupService,
        ),
      ),
    );
  }
}
