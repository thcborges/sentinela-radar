import 'package:equatable/equatable.dart';
import 'poi_model.dart';

/// Modelo de Ponto de Interesse registrado diretamente pelo usuário no aplicativo
/// (ex: novo radar móvel, blitz policial ou lombada não catalogada).
class UserReportedPoi extends Equatable {
  final int? id;
  final PoiType type;
  final double latitude;
  final double longitude;
  final int? speedLimit;
  final int? direction;
  final double toleranceAngle;
  final String roadName;
  final DateTime createdAt;
  final String? description;

  const UserReportedPoi({
    this.id,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.speedLimit,
    this.direction,
    this.toleranceAngle = 35.0,
    this.roadName = '',
    required this.createdAt,
    this.description,
  });

  /// Converte o POI customizado para o modelo operacional [PoiPoint]
  /// utilizando ID negativo para blindagem contra colisão com IDs do OSM/DNIT.
  PoiPoint toPoiPoint() {
    final effectiveId = id != null ? -id!.abs() : -1;
    return PoiPoint(
      id: effectiveId,
      type: type,
      latitude: latitude,
      longitude: longitude,
      speedLimit: speedLimit,
      direction: direction,
      toleranceAngle: toleranceAngle,
      roadName: roadName,
      source: 'user_reported',
    );
  }

  UserReportedPoi copyWith({
    int? id,
    PoiType? type,
    double? latitude,
    double? longitude,
    int? speedLimit,
    int? direction,
    double? toleranceAngle,
    String? roadName,
    DateTime? createdAt,
    String? description,
  }) {
    return UserReportedPoi(
      id: id ?? this.id,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedLimit: speedLimit ?? this.speedLimit,
      direction: direction ?? this.direction,
      toleranceAngle: toleranceAngle ?? this.toleranceAngle,
      roadName: roadName ?? this.roadName,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type.code,
      'latitude': latitude,
      'longitude': longitude,
      'speed_limit': speedLimit,
      'direction': direction,
      'tolerance_angle': toleranceAngle,
      'road_name': roadName,
      'created_at': createdAt.toIso8601String(),
      'description': description,
    };
  }

  factory UserReportedPoi.fromMap(Map<String, dynamic> map) {
    return UserReportedPoi(
      id: map['id'] as int?,
      type: PoiType.fromCode(map['type'] as int),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      speedLimit: map['speed_limit'] as int?,
      direction: map['direction'] as int?,
      toleranceAngle: (map['tolerance_angle'] as num?)?.toDouble() ?? 35.0,
      roadName: (map['road_name'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      description: map['description'] as String?,
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
        createdAt,
        description,
      ];
}
