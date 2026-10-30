import 'dart:math' as math;
import 'poi_model.dart';

/// Utilitário matemático para cálculo dinâmico da distância de alerta
/// e raio de aproximação adaptativo com base na velocidade do veículo e no tipo de POI.
abstract class AlertDistanceCalculator {
  /// Calcula a distância dinâmica ideal de disparo de alerta em metros:
  ///
  /// $$D_{alerta} = \max(D_{min},\, v \cdot t_{antecipacao})$$
  static double calculateAlertDistance(
    PoiType type,
    double speedKmh, {
    double? customAnticipationSeconds,
  }) {
    final speedMs = math.max(0.0, speedKmh) / 3.6;
    final seconds = customAnticipationSeconds ?? type.defaultAnticipationSeconds;
    final dynamicDistance = speedMs * seconds;
    return math.max(type.minAlertDistanceMeters, dynamicDistance);
  }

  /// Calcula a distância preliminar de aproximação (estado APPROACHING),
  /// fornecendo margem para preparação de HUD e busca espacial.
  static double calculateApproachingDistance(
    PoiType type,
    double speedKmh, {
    double? customAnticipationSeconds,
  }) {
    return calculateAlertDistance(
          type,
          speedKmh,
          customAnticipationSeconds: customAnticipationSeconds,
        ) *
        1.5;
  }
}
