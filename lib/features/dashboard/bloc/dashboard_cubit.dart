import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/geo/bearing.dart';
import 'package:sentinela/core/geo/haversine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/repository/poi_repository.dart';

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

  const DashboardState({
    this.currentSpeedKmh = 0.0,
    this.currentBearing = 0.0,
    this.roadName = 'Monitorando vias...',
    this.activeAlert,
    this.alertStatus = AlertStatus.idle,
    this.nearbySonarPois = const [],
    this.isGpsFixValid = false,
    this.totalPoisCount = 0,
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
      ];
}

/// Cubit responsável por orquestrar o fluxo de dados do GPS, o Sonar frontal
/// e a Máquina de Estados de Alerta.
class DashboardCubit extends Cubit<DashboardState> {
  final PoiRepository _repository;
  final AlertMachine _alertMachine;

  DashboardCubit({
    required PoiRepository repository,
    required AlertMachine alertMachine,
  })  : _repository = repository,
        _alertMachine = alertMachine,
        super(const DashboardState());

  /// Processa cada coordenada recebida do GPS nativo.
  Future<void> onLocationUpdated(VehiclePosition position) async {
    if (!position.isAccurate) {
      emit(state.copyWith(
        currentSpeedKmh: position.speedKmh,
        currentBearing: position.bearing,
        isGpsFixValid: false,
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
    _alertMachine.updatePosition(position, filteredPois);
    final alertState = _alertMachine.state;
    final activeAlert = alertState.activeAlert;

    // 5. Determina nome da via para exibição no topo
    String activeRoad = 'Monitorando vias...';
    if (activeAlert != null && activeAlert.poi.roadName.isNotEmpty) {
      activeRoad = activeAlert.poi.roadName;
    } else if (filteredPois.isNotEmpty && filteredPois.first.roadName.isNotEmpty) {
      activeRoad = filteredPois.first.roadName;
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
    ));
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

  /// Define contagem inicial de POIs na base para exibição de métricas.
  void setInitialPoiCount(int count) {
    emit(state.copyWith(totalPoisCount: count));
  }
}
