import 'package:equatable/equatable.dart';
import '../../../core/models/poi_model.dart';

/// Registro individual de passagem por um ponto fiscalizado (100% privado e local).
class PassageRecord extends Equatable {
  final int? id;
  final int poiId;
  final PoiType poiType;
  final double vehicleSpeedKmh;
  final int? speedLimit;
  final DateTime timestamp;
  final bool isOverSpeed;
  final String roadName;
  final double? tollFee;
  final double? latitude;
  final double? longitude;

  const PassageRecord({
    this.id,
    required this.poiId,
    required this.poiType,
    required this.vehicleSpeedKmh,
    this.speedLimit,
    required this.timestamp,
    required this.isOverSpeed,
    this.roadName = '',
    this.tollFee,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'poi_id': poiId,
      'poi_type': poiType.code,
      'vehicle_speed': vehicleSpeedKmh,
      'speed_limit': speedLimit,
      'timestamp': timestamp.toIso8601String(),
      'is_over_speed': isOverSpeed ? 1 : 0,
      'road_name': roadName,
      if (tollFee != null) 'toll_fee': tollFee,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  factory PassageRecord.fromMap(Map<String, dynamic> map) {
    return PassageRecord(
      id: map['id'] as int?,
      poiId: map['poi_id'] as int,
      poiType: PoiType.fromCode(map['poi_type'] as int),
      vehicleSpeedKmh: (map['vehicle_speed'] as num).toDouble(),
      speedLimit: map['speed_limit'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isOverSpeed: (map['is_over_speed'] as int) == 1,
      roadName: (map['road_name'] as String?) ?? '',
      tollFee: (map['toll_fee'] as num?)?.toDouble(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        poiId,
        poiType,
        vehicleSpeedKmh,
        speedLimit,
        timestamp,
        isOverSpeed,
        roadName,
        tollFee,
        latitude,
        longitude,
      ];
}

/// Resumo analítico das estatísticas locais de conformidade de velocidade e pedágios.
class StatsSummary extends Equatable {
  final int totalPassages;
  final int overSpeedPassages;
  final double totalTollCost;

  const StatsSummary({
    required this.totalPassages,
    required this.overSpeedPassages,
    this.totalTollCost = 0.0,
  });

  int get compliantPassages => totalPassages - overSpeedPassages;

  double get adherenceRatePercent {
    if (totalPassages == 0) return 100.0;
    return (compliantPassages / totalPassages) * 100.0;
  }

  @override
  List<Object?> get props => [totalPassages, overSpeedPassages, totalTollCost];
}
