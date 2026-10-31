import '../models/poi_model.dart';
import 'package:sentinela/features/stats/models/passage_record.dart';

/// Categorias de veículos para modulação tarifária de pedágios e Free Flow.
enum VehicleCategory {
  car(factor: 1.0, label: 'Passeio / Automóvel'),
  motorcycle(factor: 0.5, label: 'Motocicleta'),
  commercial(factor: 2.0, label: 'Comercial 2 Eixos'),
  heavyTruck(factor: 4.0, label: 'Caminhão Pesado');

  final double factor;
  final String label;

  const VehicleCategory({required this.factor, required this.label});
}

/// Resumo acumulado de custos e passagens em pedágios de um trajeto.
class TripTollSummary {
  final double totalCost;
  final int tollBoothCount;
  final int freeFlowCount;
  final int totalTollPoints;

  const TripTollSummary({
    required this.totalCost,
    required this.tollBoothCount,
    required this.freeFlowCount,
    required this.totalTollPoints,
  });

  String formatCurrency({double? amount}) {
    final val = amount ?? totalCost;
    return 'R\$ ${val.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}

/// Motor determinístico offline para cálculo e estimativa de tarifas de pedágio.
class TollRateEstimator {
  final Map<int, double> _customPoiRates;

  /// Tarifa padrão estimada de referência para pórticos Free Flow no Brasil (ex: SP-099 Tamoios / Rio-Santos BR-101).
  static const double defaultFreeFlowRate = 4.20;

  /// Tarifa média estimada de referência para praças de pedágio convencionais concessionadas.
  static const double defaultTollBoothRate = 8.50;

  const TollRateEstimator({
    Map<int, double>? customPoiRates,
  }) : _customPoiRates = customPoiRates ?? const {};

  /// Estima o custo de tarifa do POI com base no tipo e na categoria veicular.
  double estimateToll(
    PoiPoint poi, {
    VehicleCategory category = VehicleCategory.car,
  }) {
    if (poi.type != PoiType.tollBooth && poi.type != PoiType.freeFlowToll) {
      return 0.0;
    }

    final double baseRate;
    if (_customPoiRates.containsKey(poi.id)) {
      baseRate = _customPoiRates[poi.id]!;
    } else if (poi.type == PoiType.freeFlowToll) {
      baseRate = defaultFreeFlowRate;
    } else {
      baseRate = defaultTollBoothRate;
    }

    return baseRate * category.factor;
  }

  /// Calcula o resumo de custos de pedágio a partir de uma lista de registros de passagens.
  TripTollSummary calculateTripSummary(List<PassageRecord> passages) {
    double totalCost = 0.0;
    int tollBoothCount = 0;
    int freeFlowCount = 0;

    for (final passage in passages) {
      if (passage.poiType == PoiType.freeFlowToll) {
        freeFlowCount++;
        totalCost += passage.tollFee ?? defaultFreeFlowRate;
      } else if (passage.poiType == PoiType.tollBooth) {
        tollBoothCount++;
        totalCost += passage.tollFee ?? defaultTollBoothRate;
      }
    }

    return TripTollSummary(
      totalCost: totalCost,
      tollBoothCount: tollBoothCount,
      freeFlowCount: freeFlowCount,
      totalTollPoints: tollBoothCount + freeFlowCount,
    );
  }
}
