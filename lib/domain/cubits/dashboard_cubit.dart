import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../automotive/automotive_service.dart';
import '../automotive/car_app_models.dart';
import '../engines/alert_machine.dart';
import '../engines/poi_cluster_engine.dart';
import '../engines/section_control_machine.dart';
import '../l10n/app_language.dart';
import '../math/bearing.dart';
import '../math/dead_reckoning_engine.dart';
import '../math/haversine.dart';
import '../math/solar_calculator.dart';
import '../models/poi_model.dart';
import '../models/user_reported_poi.dart';
import '../models/vehicle_profile.dart';
import 'package:sentinela/infrastructure/platform/haptic_feedback_engine.dart';
import 'package:sentinela/infrastructure/platform/live_activity_service.dart';
import 'package:sentinela/infrastructure/repositories/custom_poi_repository.dart';
import 'package:sentinela/infrastructure/repositories/poi_repository.dart';

/// Representação de um POI para visualização no Sonar Circular frontal.
class SonarPoiItem extends Equatable {
  final PoiPoint poi;
  final double distanceMeters;

  /// Ângulo relativo em relação ao rumo do veículo (-90° esquerda a +90° direita).
  final double relativeAngleDeg;

  const SonarPoiItem({
    required this.poi,
    required this.distanceMeters,
    required this.relativeAngleDeg,
  });

  @override
  List<Object?> get props => [poi, distanceMeters, relativeAngleDeg];
}

/// Estado imutável do Dashboard do condutor.
class DashboardState extends Equatable {
  final double currentSpeedKmh;
  final double currentBearing;
  final String roadName;
  final ActiveAlert? activeAlert;
  final AlertStatus alertStatus;
  final List<SonarPoiItem> nearbySonarPois;
  final bool isGpsFixValid;
  final int totalPoisCount;
  final Set<PoiType> enabledPoiTypes;
  final bool isHudMirrorMode;
  final SectionControlState sectionControlState;
  final VehiclePosition? lastPosition;
  final int userPoiCount;
  final VehicleProfile vehicleProfile;
  final DeadReckoningStatus deadReckoningStatus;
  final HudThemeMode hudThemeMode;
  final bool isDaytime;
  final PoiCluster? activeCluster;
  final bool hapticEnabled;
  final HapticIntensity hapticIntensity;
  final AppLanguage language;
  final bool highContrastMode;
  final CarConnectionStatus carConnectionStatus;

  const DashboardState({
    this.currentSpeedKmh = 0.0,
    this.currentBearing = 0.0,
    this.roadName = 'Monitorando vias...',
    this.activeAlert,
    this.alertStatus = AlertStatus.idle,
    this.nearbySonarPois = const [],
    this.isGpsFixValid = false,
    this.totalPoisCount = 0,
    this.isHudMirrorMode = false,
    this.sectionControlState = const SectionControlState(),
    this.lastPosition,
    this.userPoiCount = 0,
    this.vehicleProfile = const VehicleProfile(type: VehicleType.car, name: 'Automóvel / Utilitário'),
    this.deadReckoningStatus = DeadReckoningStatus.searchingSignal,
    this.hudThemeMode = HudThemeMode.darkOnly,
    this.isDaytime = false,
    this.activeCluster,
    this.hapticEnabled = true,
    this.hapticIntensity = HapticIntensity.medium,
    this.language = AppLanguage.pt,
    this.highContrastMode = false,
    this.carConnectionStatus = CarConnectionStatus.disconnected,
    this.enabledPoiTypes = const {
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
  });

  /// Indica se a navegação inercial em túnel está ativa no momento.
  bool get isTunnelMode => deadReckoningStatus == DeadReckoningStatus.deadReckoning;

  /// Resolve dinamicamente se o tema atual a ser renderizado na UI deve ser escuro.
  bool get isEffectiveThemeDark => hudThemeMode.shouldUseDarkTheme(
        isDaytime: isDaytime,
        isTunnel: isTunnelMode,
      );

  DashboardState copyWith({
    double? currentSpeedKmh,
    double? currentBearing,
    String? roadName,
    ActiveAlert? activeAlert,
    bool clearActiveAlert = false,
    AlertStatus? alertStatus,
    List<SonarPoiItem>? nearbySonarPois,
    bool? isGpsFixValid,
    int? totalPoisCount,
    Set<PoiType>? enabledPoiTypes,
    bool? isHudMirrorMode,
    SectionControlState? sectionControlState,
    VehiclePosition? lastPosition,
    int? userPoiCount,
    VehicleProfile? vehicleProfile,
    DeadReckoningStatus? deadReckoningStatus,
    HudThemeMode? hudThemeMode,
    bool? isDaytime,
    PoiCluster? activeCluster,
    bool clearActiveCluster = false,
    bool? hapticEnabled,
    HapticIntensity? hapticIntensity,
    AppLanguage? language,
    bool? highContrastMode,
    CarConnectionStatus? carConnectionStatus,
  }) {
    return DashboardState(
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      currentBearing: currentBearing ?? this.currentBearing,
      roadName: roadName ?? this.roadName,
      activeAlert: clearActiveAlert ? null : (activeAlert ?? this.activeAlert),
      alertStatus: alertStatus ?? this.alertStatus,
      nearbySonarPois: nearbySonarPois ?? this.nearbySonarPois,
      isGpsFixValid: isGpsFixValid ?? this.isGpsFixValid,
      totalPoisCount: totalPoisCount ?? this.totalPoisCount,
      enabledPoiTypes: enabledPoiTypes ?? this.enabledPoiTypes,
      isHudMirrorMode: isHudMirrorMode ?? this.isHudMirrorMode,
      sectionControlState: sectionControlState ?? this.sectionControlState,
      lastPosition: lastPosition ?? this.lastPosition,
      userPoiCount: userPoiCount ?? this.userPoiCount,
      vehicleProfile: vehicleProfile ?? this.vehicleProfile,
      deadReckoningStatus: deadReckoningStatus ?? this.deadReckoningStatus,
      hudThemeMode: hudThemeMode ?? this.hudThemeMode,
      isDaytime: isDaytime ?? this.isDaytime,
      activeCluster: clearActiveCluster ? null : (activeCluster ?? this.activeCluster),
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      hapticIntensity: hapticIntensity ?? this.hapticIntensity,
      language: language ?? this.language,
      highContrastMode: highContrastMode ?? this.highContrastMode,
      carConnectionStatus: carConnectionStatus ?? this.carConnectionStatus,
    );
  }

  @override
  List<Object?> get props => [
        currentSpeedKmh,
        currentBearing,
        roadName,
        activeAlert,
        alertStatus,
        nearbySonarPois,
        isGpsFixValid,
        totalPoisCount,
        enabledPoiTypes,
        isHudMirrorMode,
        sectionControlState,
        lastPosition,
        userPoiCount,
        vehicleProfile,
        deadReckoningStatus,
        hudThemeMode,
        isDaytime,
        activeCluster,
        hapticEnabled,
        hapticIntensity,
        language,
        highContrastMode,
        carConnectionStatus,
      ];
}

/// Cubit responsável por orquestrar o fluxo de dados do GPS, o Sonar frontal
/// e a Máquina de Estados de Alerta.
class DashboardCubit extends Cubit<DashboardState> {
  final PoiRepository _repository;
  final AlertMachine _alertMachine;
  final LiveActivityService? _liveActivityService;
  final SectionControlMachine? _sectionControlMachine;
  final CustomPoiRepository? _customPoiRepository;
  final DeadReckoningEngine? _deadReckoningEngine;
  final PoiClusterEngine? _poiClusterEngine;
  final HapticFeedbackEngine _hapticEngine;
  final AutomotiveService? _automotiveService;

  DashboardCubit({
    required PoiRepository repository,
    required AlertMachine alertMachine,
    LiveActivityService? liveActivityService,
    SectionControlMachine? sectionControlMachine,
    CustomPoiRepository? customPoiRepository,
    DeadReckoningEngine? deadReckoningEngine,
    PoiClusterEngine? poiClusterEngine,
    HapticFeedbackEngine? hapticEngine,
    AutomotiveService? automotiveService,
  })  : _repository = repository,
        _alertMachine = alertMachine,
        _liveActivityService = liveActivityService,
        _sectionControlMachine = sectionControlMachine,
        _customPoiRepository = customPoiRepository,
        _deadReckoningEngine = deadReckoningEngine,
        _poiClusterEngine = poiClusterEngine,
        _hapticEngine = hapticEngine ?? HapticFeedbackEngine(),
        _automotiveService = automotiveService,
        super(const DashboardState()) {
    _automotiveService?.onCarAction = (action) async {
      switch (action) {
        case CarAction.quickReportRadar:
          await reportQuickPoi(type: PoiType.mobileRadar);
          break;
        case CarAction.quickReportSpeedBump:
          await reportQuickPoi(type: PoiType.physicalSpeedBump);
          break;
        case CarAction.toggleMute:
          final prefs = _alertMachine.preferences;
          _alertMachine.updatePreferences(
            prefs.copyWith(voiceEnabled: !prefs.voiceEnabled),
          );
          break;
        case CarAction.toggleHudTheme:
          toggleHudMirrorMode();
          break;
        case CarAction.dismissAlert:
          _alertMachine.reset();
          break;
      }
    };
  }

  AlertMachine get alertMachine => _alertMachine;
  SectionControlMachine? get sectionControlMachine => _sectionControlMachine;
  CustomPoiRepository? get customPoiRepository => _customPoiRepository;
  DeadReckoningEngine? get deadReckoningEngine => _deadReckoningEngine;
  PoiClusterEngine? get poiClusterEngine => _poiClusterEngine;
  HapticFeedbackEngine get hapticEngine => _hapticEngine;
  AutomotiveService? get automotiveService => _automotiveService;

  /// Atualiza preferências táteis de feedback háptico.
  void setHapticFeedback({bool? enabled, HapticIntensity? intensity}) {
    emit(state.copyWith(
      hapticEnabled: enabled ?? state.hapticEnabled,
      hapticIntensity: intensity ?? state.hapticIntensity,
    ));
  }

  /// Define o idioma ativo na interface e nas mensagens de áudio/acessibilidade.
  void setLanguage(AppLanguage language) {
    emit(state.copyWith(language: language));
  }

  /// Ativa ou desativa o modo de alto contraste para acessibilidade visual e luz solar intensa.
  void setHighContrastMode(bool enabled) {
    emit(state.copyWith(highContrastMode: enabled));
  }

  /// Atualiza o perfil veicular (CTB) ativo no Dashboard e na máquina de alertas.
  void setVehicleProfile(VehicleProfile profile) {
    _alertMachine.updateVehicleProfile(profile);
    emit(state.copyWith(vehicleProfile: profile));
  }

  /// Define o modo de tema visual do painel HUD.
  void setHudThemeMode(HudThemeMode mode) {
    emit(state.copyWith(hudThemeMode: mode));
  }

  /// Executa passo de projeção do Dead Reckoning em caso de perda de GPS / túnel.
  Future<VehiclePosition?> tickDeadReckoning(DateTime now) async {
    final projected = _deadReckoningEngine?.projectPosition(now);
    if (projected != null) {
      await onLocationUpdated(projected, isDeadReckoning: true);
    } else {
      emit(state.copyWith(
        deadReckoningStatus:
            _deadReckoningEngine?.status ?? DeadReckoningStatus.searchingSignal,
      ));
    }
    return projected;
  }

  /// Processa cada coordenada recebida do GPS nativo ou extrapolação inercial.
  Future<void> onLocationUpdated(
    VehiclePosition position, {
    bool isDeadReckoning = false,
  }) async {
    final isDay = SolarCalculator.isDaytime(
      latitude: position.latitude,
      longitude: position.longitude,
      time: position.timestamp,
    );

    // Atualiza odometria inercial / Dead Reckoning se for fix real de satélite
    if (!isDeadReckoning) {
      _deadReckoningEngine?.updateWithGps(position);
    }
    final drStatus = _deadReckoningEngine?.status ??
        (position.isAccurate
            ? DeadReckoningStatus.gpsLocked
            : DeadReckoningStatus.searchingSignal);

    if (!position.isAccurate && !isDeadReckoning) {
      emit(state.copyWith(
        currentSpeedKmh: position.speedKmh,
        currentBearing: position.bearing,
        isGpsFixValid: false,
        lastPosition: position,
        isDaytime: isDay,
        deadReckoningStatus: drStatus,
      ));
      return;
    }

    // 1. Busca POIs próximos via R*Tree Bounding Box e Haversine (raio de 1200m)
    final nearbyFromDb = await _repository.findNearbyPois(
      latitude: position.latitude,
      longitude: position.longitude,
      radiusMeters: 1200.0,
    );

    // 2. Filtra pelas categorias de alerta ativas no painel de configurações
    final filteredPois = nearbyFromDb
        .where((poi) => state.enabledPoiTypes.contains(poi.type))
        .toList();

    // 3. Monta os pontos do Sonar circular dentro do cone frontal (±90°)
    final List<SonarPoiItem> sonarItems = [];
    for (final poi in filteredPois) {
      final distance = haversineDistance(
        position.latitude,
        position.longitude,
        poi.latitude,
        poi.longitude,
      );

      final targetAngle = initialBearing(
        position.latitude,
        position.longitude,
        poi.latitude,
        poi.longitude,
      );

      var relAngle = (targetAngle - position.bearing) % 360;
      if (relAngle > 180) relAngle -= 360;
      if (relAngle < -180) relAngle += 360;

      // Sonar frontal cobre ±90 graus
      if (relAngle >= -90 && relAngle <= 90) {
        sonarItems.add(SonarPoiItem(
          poi: poi,
          distanceMeters: distance,
          relativeAngleDeg: relAngle,
        ));
      }
    }

    // 4. Executa a máquina de estados de alerta com os POIs filtrados
    _alertMachine.updatePosition(position, filteredPois, isDeadReckoning: isDeadReckoning);
    final alertState = _alertMachine.state;
    final activeAlert = alertState.activeAlert;

    // Disparo háptico tátil conforme severidade do alerta (não bloqueia telemetria de GPS)
    if (activeAlert != null) {
      unawaited(_hapticEngine.triggerForAlert(
        activeAlert,
        hapticEnabled: state.hapticEnabled,
        intensity: state.hapticIntensity,
      ));
    } else if (alertState.status == AlertStatus.passed) {
      unawaited(_hapticEngine.triggerPoiPassed(
        hapticEnabled: state.hapticEnabled,
        intensity: state.hapticIntensity,
      ));
    }

    // 5. Determina nome da via para exibição no topo
    String activeRoad = 'Monitorando vias...';
    if (activeAlert != null && activeAlert.poi.roadName.isNotEmpty) {
      activeRoad = activeAlert.poi.roadName;
    } else if (filteredPois.isNotEmpty && filteredPois.first.roadName.isNotEmpty) {
      activeRoad = filteredPois.first.roadName;
    }

    // 6. Atualiza máquina de radar de trecho / velocidade média
    _sectionControlMachine?.updatePosition(position);
    final sectionState = _sectionControlMachine?.state ?? state.sectionControlState;

    // 7. Clusterização espacial de POIs para evitar alertas sonoros e visuais sobrepostos
    PoiCluster? matchedCluster;
    final clusterEngine = _poiClusterEngine;
    if (clusterEngine != null && filteredPois.isNotEmpty) {
      final clusters = clusterEngine.clusterPois(filteredPois);
      if (activeAlert != null) {
        for (final c in clusters) {
          if (c.allPois.any((p) => p.id == activeAlert.poi.id)) {
            matchedCluster = c;
            break;
          }
        }
      }
    }

    emit(state.copyWith(
      currentSpeedKmh: position.speedKmh,
      currentBearing: position.bearing,
      roadName: activeRoad,
      activeAlert: activeAlert,
      clearActiveAlert: activeAlert == null,
      alertStatus: alertState.status,
      nearbySonarPois: sonarItems,
      isGpsFixValid: true,
      sectionControlState: sectionState,
      lastPosition: position,
      isDaytime: isDay,
      deadReckoningStatus: drStatus,
      activeCluster: matchedCluster,
      clearActiveCluster: matchedCluster == null,
    ));

    final isAlert = activeAlert != null && alertState.status != AlertStatus.idle;
    await _liveActivityService?.updateActivity(
      LiveActivityData(
        currentSpeedKmh: position.speedKmh,
        speedLimitKmh: activeAlert?.poi.speedLimit,
        alertStatus: alertState.status,
        poiType: activeAlert?.poi.type,
        distanceMeters: activeAlert?.distanceMeters,
        roadName: activeRoad,
        isAlertActive: isAlert,
      ),
    );

    final carSonar = sonarItems.map((s) => CarSonarItem(
      label: s.poi.type.label,
      distanceMeters: s.distanceMeters,
      relativeAngleDeg: s.relativeAngleDeg,
      poiType: s.poi.type,
      isCritical: activeAlert?.poi.id == s.poi.id && alertState.status == AlertStatus.overSpeed,
    )).toList();

    await _automotiveService?.updateWithPosition(
      position: position,
      roadName: activeRoad,
      activeAlert: activeAlert,
      alertStatus: alertState.status,
      sonarItems: carSonar,
      isNightMode: state.isEffectiveThemeDark,
      isMuted: !_alertMachine.preferences.voiceEnabled,
    );
  }

  /// Alterna ativação de uma categoria de POI específica (ex: silenciar lombadas).
  void togglePoiType(PoiType type, bool enabled) {
    final updated = Set<PoiType>.from(state.enabledPoiTypes);
    if (enabled) {
      updated.add(type);
    } else {
      updated.remove(type);
    }
    emit(state.copyWith(enabledPoiTypes: updated));
  }

  /// Alterna o modo espelho HUD (projeção no para-brisa em condução noturna).
  void toggleHudMirrorMode() {
    emit(state.copyWith(isHudMirrorMode: !state.isHudMirrorMode));
  }

  /// Define explicitamente o modo espelho HUD.
  void setHudMirrorMode(bool enabled) {
    emit(state.copyWith(isHudMirrorMode: enabled));
  }

  /// Define contagem inicial de POIs na base para exibição de métricas.
  void setInitialPoiCount(int count) {
    emit(state.copyWith(totalPoisCount: count));
  }

  /// Reseta manualmente o monitoramento do radar de trecho ativo.
  void resetSectionControl() {
    _sectionControlMachine?.reset();
    emit(state.copyWith(sectionControlState: const SectionControlState()));
  }

  /// Carrega a quantidade de POIs reportados/cadastrados pelo usuário localmente.
  Future<void> loadUserPoiCount() async {
    final count = await _customPoiRepository?.getCustomPoiCount() ?? 0;
    emit(state.copyWith(userPoiCount: count));
  }

  /// Registra com 1 toque um POI customizado na posição atual do condutor (ex: radar móvel avistado).
  Future<UserReportedPoi?> reportQuickPoi({
    required PoiType type,
    int? speedLimit,
    String? roadName,
    String? description,
  }) async {
    final pos = state.lastPosition;
    if (pos == null) return null;

    final userPoi = UserReportedPoi(
      type: type,
      latitude: pos.latitude,
      longitude: pos.longitude,
      speedLimit: speedLimit,
      direction: pos.bearing.round(),
      roadName: roadName ?? (state.roadName == 'Monitorando vias...' ? '' : state.roadName),
      createdAt: DateTime.now(),
      description: description,
    );

    final saved = await _customPoiRepository?.addCustomPoi(userPoi) ?? userPoi;
    unawaited(_hapticEngine.triggerQuickReport(
      hapticEnabled: state.hapticEnabled,
      intensity: state.hapticIntensity,
    ));
    await loadUserPoiCount();

    // Reexecuta varredura de POIs na posição atual para atualizar sonar e alertas imediatamente
    await onLocationUpdated(pos);

    return saved;
  }

  @override
  Future<void> close() async {
    await _liveActivityService?.stopActivity();
    _automotiveService?.dispose();
    return super.close();
  }
}
