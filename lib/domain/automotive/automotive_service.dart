import 'dart:async';
import '../engines/alert_machine.dart';
import '../models/poi_model.dart';
import 'car_app_models.dart';
import 'car_app_platform_interface.dart';

/// Serviço orquestrador para projeção do cockpit Sentinela em Android Auto & Apple CarPlay.
class AutomotiveService {
  final CarAppPlatformInterface _platform;
  StreamSubscription<CarConnectionStatus>? _subscription;

  CarConnectionStatus _currentConnection = CarConnectionStatus.disconnected;
  CarAppData _lastData = const CarAppData();
  void Function(CarAction action)? onCarAction;

  AutomotiveService({CarAppPlatformInterface? platform})
      : _platform = platform ?? PlatformCarAppAdapter() {
    _init();
  }

  bool get isConnected => _currentConnection.isConnected;
  CarConnectionStatus get currentConnection => _currentConnection;
  CarAppData get lastData => _lastData;
  CarAppPlatformInterface get platform => _platform;

  void _init() {
    _platform.setActionHandler((action) {
      onCarAction?.call(action);
    });

    _subscription = _platform.connectionStream.listen((status) async {
      _currentConnection = status;
      if (status.isConnected) {
        await _platform.startSession();
        await _platform.updateDisplay(_lastData.copyWith(connectionStatus: status));
      } else {
        await _platform.stopSession();
      }
    });

    // Consulta inicial do status
    _platform.getConnectionStatus().then((status) {
      _currentConnection = status;
    });
  }

  /// Calcula o nível de distração veicular com base na velocidade de deslocamento.
  CarDistractionLevel _evaluateDistractionLevel(double speedKmh) {
    if (speedKmh <= 5.0) {
      return CarDistractionLevel.parked;
    } else if (speedKmh > 80.0) {
      return CarDistractionLevel.highSpeed;
    } else {
      return CarDistractionLevel.driving;
    }
  }

  /// Determina as ações rápidas permitidas no console conforme regras de distração ao volante.
  List<CarAction> _resolveAllowedActions(CarDistractionLevel level, {bool isMuted = false}) {
    switch (level) {
      case CarDistractionLevel.parked:
        return const [
          CarAction.quickReportRadar,
          CarAction.quickReportSpeedBump,
          CarAction.toggleMute,
          CarAction.toggleHudTheme,
          CarAction.dismissAlert,
        ];
      case CarDistractionLevel.driving:
        return const [
          CarAction.quickReportRadar,
          CarAction.quickReportSpeedBump,
          CarAction.toggleMute,
          CarAction.dismissAlert,
        ];
      case CarDistractionLevel.highSpeed:
        return const [
          CarAction.quickReportRadar,
          CarAction.toggleMute,
        ];
    }
  }

  /// Transmite dados atualizados de GPS, alertas e via para o painel do carro.
  Future<bool> updateWithPosition({
    required VehiclePosition position,
    String roadName = 'Monitorando vias...',
    ActiveAlert? activeAlert,
    AlertStatus alertStatus = AlertStatus.idle,
    List<CarSonarItem> sonarItems = const [],
    bool isNightMode = true,
    bool isMuted = false,
  }) async {
    final distraction = _evaluateDistractionLevel(position.speedKmh);
    final allowedActions = _resolveAllowedActions(distraction, isMuted: isMuted);

    // Filtra no máximo 3 itens de sonar mais próximos no cone frontal para evitar sobrecarga cognitiva
    final filteredSonar = (sonarItems.length > 3)
        ? sonarItems.take(3).toList()
        : sonarItems;

    _lastData = CarAppData(
      currentSpeedKmh: position.speedKmh,
      speedLimitKmh: activeAlert?.poi.speedLimit,
      roadName: roadName,
      alertStatus: alertStatus,
      activeAlert: activeAlert,
      connectionStatus: _currentConnection,
      isMuted: isMuted,
      isNightMode: isNightMode,
      distractionLevel: distraction,
      simplifiedSonarItems: filteredSonar,
      allowedActions: allowedActions,
    );

    if (_currentConnection.isConnected) {
      return await _platform.updateDisplay(_lastData);
    }
    return false;
  }

  /// Encerra a subscrição e a sessão veicular.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    if (_currentConnection.isConnected) {
      _platform.stopSession();
    }
  }
}
