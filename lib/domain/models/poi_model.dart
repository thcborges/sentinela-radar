import 'package:equatable/equatable.dart';

/// Classificação padronizada de Pontos de Interesse (POIs) viários no Brasil.
enum PoiType {
  /// 1: Radar fixo tradicional de velocidade
  fixedRadar(1, 'Radar Fixo', 15, 200.0),

  /// 2: Ponto com autorização/histórico de radar móvel ou estático
  mobileRadar(2, 'Radar Móvel', 15, 200.0),

  /// 3: Semáforo com radar (velocidade + avanço de sinal vermelho)
  trafficLightRadar(3, 'Semáforo c/ Radar', 10, 180.0),

  /// 4: Câmera de sinal (exclusivamente avanço de vermelho e parada sobre faixa)
  redLightCamera(4, 'Câmera de Sinal', 10, 180.0),

  /// 5: Lombada eletrônica com visor digital de velocidade
  electronicSpeedBump(5, 'Lombada Eletrônica', 8, 80.0),

  /// 6: Lombada física / quebra-molas / faixa elevada de pedestres
  physicalSpeedBump(6, 'Lombada Física', 8, 80.0),

  /// 7: Praça de pedágio convencional com cabine/cancela
  tollBooth(7, 'Praça de Pedágio', 25, 800.0),

  /// 8: Pórtico eletrônico de pedágio automático sem cancela (Free Flow)
  freeFlowToll(8, 'Pedágio Free Flow', 25, 800.0),

  /// 9: Posto fixo da Polícia Rodoviária Federal ou Estadual
  highwayPatrol(9, 'Polícia Rodoviária', 15, 500.0);

  final int code;
  final String label;
  final int defaultAnticipationSeconds;
  final double minAlertDistanceMeters;

  const PoiType(
    this.code,
    this.label,
    this.defaultAnticipationSeconds,
    this.minAlertDistanceMeters,
  );

  /// Retorna o enum a partir do código numérico ou fallback para [fixedRadar].
  static PoiType fromCode(int code) {
    for (final type in PoiType.values) {
      if (type.code == code) {
        return type;
      }
    }
    return PoiType.fixedRadar;
  }

  /// Retorna o enum a partir do nome em string ou fallback para [fixedRadar].
  static PoiType fromName(String name) {
    for (final type in PoiType.values) {
      if (type.name == name) {
        return type;
      }
    }
    return PoiType.fixedRadar;
  }

  /// Nome descritivo da categoria.
  String get displayName => label;

  /// Indica se o POI fiscaliza limite de velocidade regulamentada.
  bool get isSpeedEnforcement =>
      this == fixedRadar ||
      this == mobileRadar ||
      this == trafficLightRadar ||
      this == electronicSpeedBump;

  /// Indica se o POI fiscaliza avanço de sinal vermelho ou parada sobre faixa.
  bool get isRedLightEnforcement =>
      this == trafficLightRadar || this == redLightCamera;

  /// Indica se o POI é um redutor físico de velocidade (lombada/quebra-molas).
  bool get isSpeedBump =>
      this == physicalSpeedBump || this == electronicSpeedBump;

  /// Indica se o POI é uma praça de pedágio (convencional ou Free Flow).
  bool get isToll => this == tollBooth || this == freeFlowToll;
}

/// Representa um Ponto de Interesse (Radar, Semáforo, Lombada ou Pedágio)
/// indexado localmente.
class PoiPoint extends Equatable {
  final int id;
  final PoiType type;
  final double latitude;
  final double longitude;
  final int? speedLimit;
  final int? direction;
  final double toleranceAngle;
  final String roadName;
  final double? tollFeeCar;
  final String? operator;
  final String? city;
  final String? state;
  final String? source;

  const PoiPoint({
    required this.id,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.speedLimit,
    this.direction,
    this.toleranceAngle = 35.0,
    this.roadName = '',
    this.tollFeeCar,
    this.operator,
    this.city,
    this.state,
    this.source,
  });

  PoiPoint copyWith({
    int? id,
    PoiType? type,
    double? latitude,
    double? longitude,
    int? speedLimit,
    int? direction,
    double? toleranceAngle,
    String? roadName,
    double? tollFeeCar,
    String? operator,
    String? city,
    String? state,
    String? source,
  }) {
    return PoiPoint(
      id: id ?? this.id,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedLimit: speedLimit ?? this.speedLimit,
      direction: direction ?? this.direction,
      toleranceAngle: toleranceAngle ?? this.toleranceAngle,
      roadName: roadName ?? this.roadName,
      tollFeeCar: tollFeeCar ?? this.tollFeeCar,
      operator: operator ?? this.operator,
      city: city ?? this.city,
      state: state ?? this.state,
      source: source ?? this.source,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        latitude,
        longitude,
        speedLimit,
        direction,
        toleranceAngle,
        roadName,
        tollFeeCar,
        operator,
        city,
        state,
        source,
      ];
}

/// Representa a telemetria pontual do veículo obtida do GPS nativo.
class VehiclePosition extends Equatable {
  final double latitude;
  final double longitude;

  /// Velocidade em km/h.
  final double speedKmh;

  /// Rumo (bearing) em graus [0, 360).
  final double bearing;

  /// Raio de precisão estimada do GPS em metros (1-sigma).
  final double accuracyMeters;

  /// Data e hora do fix de GPS.
  final DateTime timestamp;

  const VehiclePosition({
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.bearing,
    required this.accuracyMeters,
    required this.timestamp,
  });

  /// Velocidade convertida em metros por segundo (m/s).
  double get speedMs => speedKmh / 3.6;

  /// Validação de qualidade do sinal de GPS. Sinais com incerteza acima de 35 metros
  /// são descartados para evitar falsos positivos.
  bool get isAccurate => accuracyMeters <= 35.0;

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        speedKmh,
        bearing,
        accuracyMeters,
        timestamp,
      ];
}
