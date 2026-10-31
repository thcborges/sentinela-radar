import 'package:equatable/equatable.dart';

/// Classificação do tipo de veículo para adequação das normas do CTB.
enum VehicleType {
  /// Automóveis, utilitários leves, SUVs, caminhonetes.
  car,

  /// Motocicletas, motonetas e ciclomotores.
  motorcycle,

  /// Caminhões, carretas, cavalos mecânicos, ônibus e veículos de grande porte.
  heavy,
}

/// Perfil de Condução e Calibração Dinâmica de Alertas por Categoria de Veículo.
///
/// Modela os tempos de frenagem adaptativos e os limites de velocidade segregados
/// estabelecidos pelo Artigo 61 do Código de Trânsito Brasileiro (CTB).
class VehicleProfile extends Equatable {
  final VehicleType type;
  final String name;

  /// Fator multiplicador da distância e tempo de antecipação.
  /// Veículos pesados demandam maior distância de desaceleração.
  final double lookaheadMultiplier;

  /// Teto máximo legal regulamentado pelo CTB em rodovias (ex: 90 km/h para pesados).
  final int? maxSpeedCapKmh;

  const VehicleProfile({
    required this.type,
    required this.name,
    this.lookaheadMultiplier = 1.0,
    this.maxSpeedCapKmh,
  });

  /// Perfil para automóveis e utilitários leves.
  factory VehicleProfile.car() => const VehicleProfile(
        type: VehicleType.car,
        name: 'Automóvel / Utilitário',
        lookaheadMultiplier: 1.0,
        maxSpeedCapKmh: null,
      );

  /// Perfil para motocicletas.
  factory VehicleProfile.motorcycle() => const VehicleProfile(
        type: VehicleType.motorcycle,
        name: 'Motocicleta',
        lookaheadMultiplier: 0.95,
        maxSpeedCapKmh: null,
      );

  /// Perfil para veículos pesados (caminhões e ônibus).
  factory VehicleProfile.heavy() => const VehicleProfile(
        type: VehicleType.heavy,
        name: 'Veículo Pesado (Caminhão/Ônibus)',
        lookaheadMultiplier: 1.40,
        maxSpeedCapKmh: 90,
      );

  /// Cria perfil padrão a partir do [VehicleType].
  factory VehicleProfile.fromType(VehicleType type) {
    switch (type) {
      case VehicleType.car:
        return VehicleProfile.car();
      case VehicleType.motorcycle:
        return VehicleProfile.motorcycle();
      case VehicleType.heavy:
        return VehicleProfile.heavy();
    }
  }

  /// Calcula o limite de velocidade regulamentado aplicável ao veículo.
  ///
  /// Se houver limite segregado específico para veículos pesados [speedLimitHeavy],
  /// ele é aplicado preferencialmente. Caso contrário, se for veículo pesado e o
  /// limite da via exceder o teto do CTB (90 km/h), aplica o teto regulamentar.
  int resolveSpeedLimit(int baseSpeedLimit, {int? speedLimitHeavy}) {
    if (type == VehicleType.heavy) {
      if (speedLimitHeavy != null) {
        return speedLimitHeavy;
      }
      if (maxSpeedCapKmh != null && baseSpeedLimit > maxSpeedCapKmh!) {
        return maxSpeedCapKmh!;
      }
    }
    return baseSpeedLimit;
  }

  VehicleProfile copyWith({
    VehicleType? type,
    String? name,
    double? lookaheadMultiplier,
    int? maxSpeedCapKmh,
  }) {
    return VehicleProfile(
      type: type ?? this.type,
      name: name ?? this.name,
      lookaheadMultiplier: lookaheadMultiplier ?? this.lookaheadMultiplier,
      maxSpeedCapKmh: maxSpeedCapKmh ?? this.maxSpeedCapKmh,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'name': name,
      'lookaheadMultiplier': lookaheadMultiplier,
      'maxSpeedCapKmh': maxSpeedCapKmh,
    };
  }

  factory VehicleProfile.fromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? 'car';
    final type = VehicleType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => VehicleType.car,
    );
    return VehicleProfile(
      type: type,
      name: map['name'] as String? ?? 'Automóvel',
      lookaheadMultiplier: (map['lookaheadMultiplier'] as num?)?.toDouble() ?? 1.0,
      maxSpeedCapKmh: map['maxSpeedCapKmh'] as int?,
    );
  }

  @override
  List<Object?> get props => [type, name, lookaheadMultiplier, maxSpeedCapKmh];
}
