import 'dart:async';
import '../../domain/models/poi_model.dart';

/// Status de permissão de acesso ao GPS do sistema operacional.
enum LocationPermissionStatus {
  denied,
  deniedForever,
  whileInUse,
  always,
}

/// Contrato desacoplado para aquisição de sinal de GPS e permissões.
/// Permite isolamento total e testes herméticos em ambiente headless Linux (CI).
abstract class LocationService {
  /// Verifica se o chip/provedor de localização (GPS) do aparelho está ativado.
  Future<bool> isLocationServiceEnabled();

  /// Retorna o estado atual de autorização do aplicativo para acessar o GPS.
  Future<LocationPermissionStatus> checkPermission();

  /// Solicita ao usuário a permissão de acesso à localização.
  Future<LocationPermissionStatus> requestPermission();

  /// Retorna um fluxo em tempo real de coordenadas de telemetria veicular.
  /// Por padrão utiliza filtro de deslocamento zero (tempo quase real) e cadência de 1000ms.
  Stream<VehiclePosition> getPositionStream({
    int distanceFilterMeters = 0,
    int intervalMs = 1000,
  });
}
