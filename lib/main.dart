import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sentinela/core/backup/backup_restore_service.dart';
import 'package:sentinela/core/diagnostics/system_diagnostics.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/engine/poi_cluster_engine.dart';
import 'package:sentinela/core/geo/dead_reckoning_engine.dart';
import 'package:sentinela/core/hardware/wakelock_manager.dart';
import 'package:sentinela/core/location/geolocator_location_service.dart';
import 'package:sentinela/core/location/location_service_interface.dart';
import 'package:sentinela/core/network/connectivity_checker.dart';
import 'package:sentinela/core/platform/live_activity_service.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/data/database/seed_database_loader.dart';
import 'package:sentinela/data/repository/custom_poi_repository.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/dashboard/screens/dashboard_screen.dart';
import 'package:sentinela/features/overlay/services/overlay_service.dart';
import 'package:sentinela/features/overlay/widgets/floating_overlay_widget.dart';
import 'package:sentinela/features/stats/bloc/stats_cubit.dart';
import 'package:sentinela/features/stats/repository/passage_repository.dart';

/// Construtor de fallback para erros de renderização, evitando tela branca em modo Release.
Widget buildErrorWidget(FlutterErrorDetails details) {
  return Material(
    color: SentinelaTheme.surfaceDark,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: SentinelaTheme.alertWarning, size: 56),
            const SizedBox(height: 16),
            const Text(
              'SENTINELA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ocorreu uma instabilidade na inicialização visual.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              details.exceptionAsString(),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = buildErrorWidget;

  String? dbPath;
  try {
    final appDir = await getApplicationDocumentsDirectory();
    dbPath = '${appDir.path}/sentinela_brasil.db';
  } catch (_) {
    dbPath = 'sentinela_brasil.db';
  }

  await SeedDatabaseLoader().ensureDatabaseInstalled(targetPath: dbPath);
  runApp(SentinelaApp(databasePath: dbPath));
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
  final String? databasePath;
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
    this.databasePath,
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
      final targetPath = widget.databasePath ?? 'sentinela_brasil.db';
      try {
        _rawDb = sqlite3.open(targetPath);
      } catch (_) {
        // Fallback gracioso para banco em memória evitando travamento no boot
        _rawDb = sqlite3.openInMemory();
      }
      _wakelockManager = widget.wakelockManager ?? PlatformWakelockManager();
      _locationService = widget.locationService ?? GeolocatorLocationService();
      _overlayService = widget.overlayService;
    }

    _dbManager = DatabaseManager(_rawDb);
    _dbManager.initializeSchema();

    final customPoiRepo = CustomPoiRepository(_rawDb);
    customPoiRepo.initializeSchema();

    _repository = PoiRepository(_dbManager, customPoiRepository: customPoiRepo);
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

    final drEngine = DeadReckoningEngine();
    const clusterEngine = PoiClusterEngine();

    _dashboardCubit = DashboardCubit(
      repository: _repository,
      alertMachine: _alertMachine,
      liveActivityService: _liveActivityService,
      customPoiRepository: customPoiRepo,
      deadReckoningEngine: drEngine,
      poiClusterEngine: clusterEngine,
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
