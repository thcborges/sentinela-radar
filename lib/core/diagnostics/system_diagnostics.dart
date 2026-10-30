import 'dart:io';
import 'package:equatable/equatable.dart';
import '../../data/database/database_manager.dart';
import '../../data/repository/poi_repository.dart';
import '../location/location_service_interface.dart';
import '../network/connectivity_checker.dart';

/// Relatório consolidado do diagnóstico de integridade do sistema Sentinela.
class DiagnosticReport extends Equatable {
  final bool isGpsHardwareEnabled;
  final LocationPermissionStatus gpsPermission;
  final bool isDatabaseHealthy;
  final int totalPoisIndexed;
  final double databaseSizeMb;
  final bool isNetworkConnected;
  final bool isWifiConnected;
  final bool isReadyForNavigation;
  final String summaryMessage;

  const DiagnosticReport({
    required this.isGpsHardwareEnabled,
    required this.gpsPermission,
    required this.isDatabaseHealthy,
    required this.totalPoisIndexed,
    required this.databaseSizeMb,
    required this.isNetworkConnected,
    required this.isWifiConnected,
    required this.isReadyForNavigation,
    required this.summaryMessage,
  });

  @override
  List<Object?> get props => [
        isGpsHardwareEnabled,
        gpsPermission,
        isDatabaseHealthy,
        totalPoisIndexed,
        databaseSizeMb,
        isNetworkConnected,
        isWifiConnected,
        isReadyForNavigation,
        summaryMessage,
      ];
}

/// Serviço de diagnóstico e monitoramento da saúde dos subsistemas.
class SystemDiagnosticsService {
  final LocationService _locationService;
  final PoiRepository _repository;
  final DatabaseManager _dbManager;
  final NetworkConnectivityChecker? _connectivityChecker;

  SystemDiagnosticsService({
    required LocationService locationService,
    required PoiRepository repository,
    required DatabaseManager dbManager,
    NetworkConnectivityChecker? connectivityChecker,
  })  : _locationService = locationService,
        _repository = repository,
        _dbManager = dbManager,
        _connectivityChecker = connectivityChecker;

  /// Executa diagnóstico completo de sensores, permissões, integridade SQLite R*Tree e rede.
  Future<DiagnosticReport> runDiagnostics({String? dbFilePath}) async {
    final gpsEnabled = await _locationService.isLocationServiceEnabled();
    final gpsPerm = await _locationService.checkPermission();

    int totalPois = 0;
    bool dbHealthy = false;
    try {
      totalPois = _dbManager.getTotalCount();
      // Executa query de teste no índice espacial R*Tree
      await _repository.findNearbyPois(
        latitude: -23.5505,
        longitude: -46.6333,
        radiusMeters: 500,
      );
      dbHealthy = true;
    } catch (_) {
      dbHealthy = false;
    }

    double sizeMb = 0.0;
    if (dbFilePath != null) {
      try {
        final f = File(dbFilePath);
        if (await f.exists()) {
          final bytes = await f.length();
          sizeMb = bytes / (1024 * 1024);
        }
      } catch (_) {}
    }

    bool isNet = false;
    bool isWifi = false;
    if (_connectivityChecker != null) {
      isNet = await _connectivityChecker.isConnected();
      isWifi = await _connectivityChecker.isWifiConnected();
    }

    final hasGpsPerm = gpsPerm == LocationPermissionStatus.whileInUse ||
        gpsPerm == LocationPermissionStatus.always;
    final ready = gpsEnabled && hasGpsPerm && dbHealthy && totalPois > 0;

    String summary;
    if (!gpsEnabled) {
      summary = 'Chip de GPS desativado no dispositivo. Ative a localização.';
    } else if (!hasGpsPerm) {
      summary = 'Permissão de GPS necessária para emitir alertas de via.';
    } else if (!dbHealthy || totalPois == 0) {
      summary = 'Base de POIs indisponível ou vazia.';
    } else {
      summary = 'Sistema 100% operacional para navegação.';
    }

    return DiagnosticReport(
      isGpsHardwareEnabled: gpsEnabled,
      gpsPermission: gpsPerm,
      isDatabaseHealthy: dbHealthy,
      totalPoisIndexed: totalPois,
      databaseSizeMb: sizeMb,
      isNetworkConnected: isNet,
      isWifiConnected: isWifi,
      isReadyForNavigation: ready,
      summaryMessage: summary,
    );
  }
}
