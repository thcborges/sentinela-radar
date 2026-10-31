import 'package:equatable/equatable.dart';
import '../audio/tts_alert_formatter.dart';
import '../math/haversine.dart';
import '../models/poi_model.dart';

/// Representa um agrupamento (cluster) de um ou mais POIs colocalizados espacialmente.
class PoiCluster extends Equatable {
  final PoiPoint primaryPoi;
  final List<PoiPoint> associatedPois;
  final double centerLatitude;
  final double centerLongitude;
  final String compositeTtsPhrase;

  const PoiCluster({
    required this.primaryPoi,
    required this.associatedPois,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.compositeTtsPhrase,
  });

  /// Lista com todos os pontos integrantes do cluster.
  List<PoiPoint> get allPois => [primaryPoi, ...associatedPois];

  /// Indica se há múltiplos pontos colocalizados neste agrupamento.
  bool get isMultiPoint => associatedPois.isNotEmpty;

  @override
  List<Object?> get props => [
        primaryPoi,
        associatedPois,
        centerLatitude,
        centerLongitude,
        compositeTtsPhrase,
      ];
}

/// Motor de Clusterização Espacial e Fusão Hierárquica de POIs Múltiplos.
///
/// Agrupa pontos de fiscalização e redutores colocalizados (ex: radar de velocidade,
/// semáforo de avanço e lombada no mesmo cruzamento), unificando alertas sonoros
/// e visuais para evitar cacofonia e poluição de tela.
class PoiClusterEngine {
  final double clusterRadiusMeters;

  const PoiClusterEngine({
    this.clusterRadiusMeters = 45.0,
  });

  /// Agrupa a lista de POIs candidatos em clusters espaciais.
  List<PoiCluster> clusterPois(List<PoiPoint> pois) {
    if (pois.isEmpty) return [];

    final List<List<PoiPoint>> groups = [];
    final Set<int> visitedPoiIds = {};

    for (int i = 0; i < pois.length; i++) {
      final current = pois[i];
      if (visitedPoiIds.contains(current.id)) continue;

      final currentGroup = <PoiPoint>[current];
      visitedPoiIds.add(current.id);

      for (int j = i + 1; j < pois.length; j++) {
        final candidate = pois[j];
        if (visitedPoiIds.contains(candidate.id)) continue;

        // Se ambos tiverem sentido e forem opostos em pista dupla, não agrupa
        if (_areOppositeDirections(current, candidate)) {
          continue;
        }

        final distance = haversineDistance(
          current.latitude,
          current.longitude,
          candidate.latitude,
          candidate.longitude,
        );

        if (distance <= clusterRadiusMeters) {
          currentGroup.add(candidate);
          visitedPoiIds.add(candidate.id);
        }
      }

      groups.add(currentGroup);
    }

    return groups.map(_buildClusterFromGroup).toList();
  }

  /// Constrói o [PoiCluster] determinando o líder por hierarquia de severidade
  /// e gerando a locução TTS composta sem redundâncias.
  PoiCluster _buildClusterFromGroup(List<PoiPoint> group) {
    if (group.length == 1) {
      final single = group.first;
      return PoiCluster(
        primaryPoi: single,
        associatedPois: const [],
        centerLatitude: single.latitude,
        centerLongitude: single.longitude,
        compositeTtsPhrase: TtsAlertFormatter.formatPoiAlert(single),
      );
    }

    // Ordena por severidade decrescente
    group.sort((a, b) => _poiSeverity(b).compareTo(_poiSeverity(a)));

    final primary = group.first;
    final associated = group.sublist(1);

    // Média de coordenadas para centróide do cluster
    final avgLat = group.fold(0.0, (sum, p) => sum + p.latitude) / group.length;
    final avgLon = group.fold(0.0, (sum, p) => sum + p.longitude) / group.length;

    final compositeTts = _formatCompositeTts(primary, associated);

    return PoiCluster(
      primaryPoi: primary,
      associatedPois: associated,
      centerLatitude: avgLat,
      centerLongitude: avgLon,
      compositeTtsPhrase: compositeTts,
    );
  }

  /// Gera a frase TTS composta elegante e livre de cacofonia.
  String _formatCompositeTts(PoiPoint primary, List<PoiPoint> associated) {
    final primaryPhrase = TtsAlertFormatter.formatPoiAlert(primary);

    final secondaryPhrases = <String>[];
    for (final sec in associated) {
      switch (sec.type) {
        case PoiType.redLightCamera:
          secondaryPhrases.add('fiscalização de sinal vermelho');
          break;
        case PoiType.physicalSpeedBump:
        case PoiType.electronicSpeedBump:
          secondaryPhrases.add('lombada');
          break;
        case PoiType.trafficLightRadar:
          secondaryPhrases.add('semáforo com radar');
          break;
        case PoiType.freeFlowToll:
          secondaryPhrases.add('Pórtico Free Flow');
          break;
        case PoiType.tollBooth:
          secondaryPhrases.add('praça de pedágio');
          break;
        case PoiType.fixedRadar:
          secondaryPhrases.add('radar fixo');
          break;
        case PoiType.mobileRadar:
          secondaryPhrases.add('radar móvel');
          break;
        case PoiType.highwayPatrol:
          secondaryPhrases.add('posto policial');
          break;
      }
    }

    if (secondaryPhrases.isEmpty) {
      return primaryPhrase;
    }

    // Remove pontuação final da frase primária para encadear
    final cleanedPrimary = primaryPhrase.replaceAll(RegExp(r'\.+$'), '');
    final combinedSecondaries = secondaryPhrases.toSet().join(' e ');

    return '$cleanedPrimary e $combinedSecondaries à frente.';
  }

  /// Verifica se dois POIs têm sentidos declarados opostos (ex: pistas duplas contrárias).
  bool _areOppositeDirections(PoiPoint a, PoiPoint b) {
    if (a.direction == null || b.direction == null) return false;
    final diff = (a.direction! - b.direction!).abs() % 360;
    final shortestAngle = diff > 180 ? 360 - diff : diff;
    return shortestAngle >= 120;
  }

  /// Pontuação de prioridade/severidade do ponto para seleção do líder.
  int _poiSeverity(PoiPoint poi) {
    switch (poi.type) {
      case PoiType.trafficLightRadar:
        return 100;
      case PoiType.fixedRadar:
        return 90;
      case PoiType.mobileRadar:
        return 80;
      case PoiType.redLightCamera:
        return 70;
      case PoiType.freeFlowToll:
        return 60;
      case PoiType.tollBooth:
        return 50;
      case PoiType.electronicSpeedBump:
        return 40;
      case PoiType.physicalSpeedBump:
        return 30;
      case PoiType.highwayPatrol:
        return 20;
    }
  }
}
