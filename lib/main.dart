import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/dashboard/screens/dashboard_screen.dart';
import 'package:sentinela/features/stats/bloc/stats_cubit.dart';
import 'package:sentinela/features/stats/repository/passage_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SentinelaApp());
}

/// Widget raiz da aplicação Sentinela.
class SentinelaApp extends StatefulWidget {
  final bool useInMemoryDb;

  const SentinelaApp({
    super.key,
    this.useInMemoryDb = false,
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

  @override
  void initState() {
    super.initState();
    if (widget.useInMemoryDb) {
      _rawDb = sqlite3.openInMemory();
    } else {
      _rawDb = sqlite3.open('sentinela_brasil.db');
    }

    _dbManager = DatabaseManager(_rawDb);
    _dbManager.initializeSchema();

    _repository = PoiRepository(_dbManager);
    _alertMachine = AlertMachine();
    _syncService = PoiSyncService(_rawDb);

    _passageRepository = PassageRepository(_rawDb);
    _passageRepository.initSchema();
    _statsCubit = StatsCubit(repository: _passageRepository);
    _statsCubit.loadStats();

    _dashboardCubit = DashboardCubit(
      repository: _repository,
      alertMachine: _alertMachine,
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
        ),
      ),
    );
  }
}
