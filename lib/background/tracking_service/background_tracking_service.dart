import 'dart:async';
import '../../core/audio/audio_alert_player.dart';
import '../../core/engine/alert_machine.dart';
import '../../core/models/poi_model.dart';
import '../../data/repository/poi_repository.dart';
import '../../features/overlay/services/overlay_service.dart';

/// Serviço orquestrador de rastreamento em segundo plano (Foreground Service).
/// Responsável por manter o GPS ativo de forma persistente (mesmo minimizado ou
/// sob o Waze/Google Maps), consultar o banco SQLite R*Tree, acionar a máquina
/// de estados de alerta, despachar avisos por voz/bipe e sincronizar a miniatura flutuante.
class BackgroundTrackingService {
  final PoiRepository _repository;
  final AlertMachine _alertMachine;
  final AudioAlertPlayer _audioPlayer;
  final OverlayService _overlayService;

  bool isVoiceEnabled;
  bool isBeepEnabled;
  Set<PoiType> enabledPoiTypes;

  bool _isRunning = false;
  ActiveAlert? _currentAlert;
  VehiclePosition? _lastPosition;
  StreamSubscription<VehiclePosition>? _gpsSubscription;

  final _alertController = StreamController<ActiveAlert?>.broadcast();
  final _positionController = StreamController<VehiclePosition>.broadcast();

  BackgroundTrackingService({
    required PoiRepository repository,
    required AlertMachine alertMachine,
    required AudioAlertPlayer audioPlayer,
    required OverlayService overlayService,
    this.isVoiceEnabled = true,
    this.isBeepEnabled = true,
    Set<PoiType>? enabledPoiTypes,
  })  : _repository = repository,
        _alertMachine = alertMachine,
        _audioPlayer = audioPlayer,
        _overlayService = overlayService,
        enabledPoiTypes = enabledPoiTypes ?? Set.from(PoiType.values);

  bool get isRunning => _isRunning;
  ActiveAlert? get currentAlert => _currentAlert;
  VehiclePosition? get lastPosition => _lastPosition;

  Stream<ActiveAlert?> get alertStream => _alertController.stream;
  Stream<VehiclePosition> get positionStream => _positionController.stream;

  /// Inicia o monitoramento contínuo em segundo plano a partir de uma stream de GPS.
  Future<void> startTracking(Stream<VehiclePosition> locationStream) async {
    await stopTracking();
    _isRunning = true;

    _gpsSubscription = locationStream.listen(
      _processGpsUpdate,
      onError: (error) {
        // Log de erro no GPS sem interromper o serviço
      },
    );
  }

  /// Processa cada coordenada recebida do GPS nativo.
  Future<void> _processGpsUpdate(VehiclePosition position) async {
    if (!position.isAccurate) return;

    _lastPosition = position;
    _positionController.add(position);

    // 1. Busca POIs no índice espacial SQLite R*Tree (raio de 1200 metros)
    final nearbyPois = await _repository.findNearbyPois(
      latitude: position.latitude,
      longitude: position.longitude,
      radiusMeters: 1200.0,
    );

    // 2. Filtra pelas categorias ativas no painel de configurações
    final filteredPois = nearbyPois
        .where((poi) => enabledPoiTypes.contains(poi.type))
        .toList();

    // 3. Atualiza a máquina de estados de alerta
    _alertMachine.updatePosition(position, filteredPois);
    final alert = _alertMachine.state.activeAlert;
    _currentAlert = alert;
    _alertController.add(alert);

    // 4. Dispara alerta sonoro e vocal via TTS
    if (alert != null) {
      await _audioPlayer.playAlert(
        alert,
        isVoiceEnabled: isVoiceEnabled,
        isBeepEnabled: isBeepEnabled,
      );
    }

    // 5. Envia dados para o Overlay Flutuante / Dynamic Island
    await _overlayService.updateOverlayData(
      speedKmh: position.speedKmh,
      alert: alert,
    );
  }

  /// Para o serviço de segundo plano e limpa os recursos de subscrição.
  Future<void> stopTracking() async {
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _isRunning = false;
    _currentAlert = null;
    _lastPosition = null;
    _alertMachine.reset();
    _audioPlayer.reset();
  }

  /// Encerra permanentemente todos os canais do serviço.
  Future<void> dispose() async {
    await stopTracking();
    await _alertController.close();
    await _positionController.close();
  }
}
