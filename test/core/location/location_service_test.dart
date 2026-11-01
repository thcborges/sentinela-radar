import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/location/geolocator_location_service.dart';
import 'package:sentinela/core/location/location_service_interface.dart';
import 'package:sentinela/core/models/poi_model.dart';

class MockGeolocatorPlatform extends Mock implements GeolocatorPlatform {}

class FakeLocationService implements LocationService {
  bool serviceEnabled = true;
  LocationPermissionStatus currentPermission = LocationPermissionStatus.denied;
  final StreamController<VehiclePosition> _controller =
      StreamController<VehiclePosition>.broadcast();

  @override
  int get defaultIntervalMs => 250;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async => currentPermission;

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    if (currentPermission == LocationPermissionStatus.denied) {
      currentPermission = LocationPermissionStatus.whileInUse;
    }
    return currentPermission;
  }

  @override
  Stream<VehiclePosition> getPositionStream({
    int distanceFilterMeters = 2,
    int intervalMs = 1000,
  }) {
    return _controller.stream;
  }

  void emitPosition(VehiclePosition position) {
    _controller.add(position);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('LocationService Interface and FakeLocationService Tests (BDD)', () {
    late FakeLocationService locationService;

    setUp(() {
      locationService = FakeLocationService();
    });

    tearDown(() {
      locationService.dispose();
    });

    test('Deve reportar se o serviço de GPS está ativo', () async {
      expect(await locationService.isLocationServiceEnabled(), isTrue);

      locationService.serviceEnabled = false;
      expect(await locationService.isLocationServiceEnabled(), isFalse);
    });

    test('Deve verificar e solicitar permissão de localização', () async {
      expect(await locationService.checkPermission(),
          equals(LocationPermissionStatus.denied));

      final requested = await locationService.requestPermission();
      expect(requested, equals(LocationPermissionStatus.whileInUse));
      expect(await locationService.checkPermission(),
          equals(LocationPermissionStatus.whileInUse));
    });

    test('Deve emitir fluxo contínuo de coordenadas de VehiclePosition', () async {
      final positions = <VehiclePosition>[];
      final sub = locationService.getPositionStream().listen(positions.add);

      final now = DateTime(2026, 10, 30, 10, 0);
      final pos1 = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 60.0,
        bearing: 90.0,
        accuracyMeters: 5.0,
        timestamp: now,
      );
      final pos2 = VehiclePosition(
        latitude: -23.5510,
        longitude: -46.6340,
        speedKmh: 65.0,
        bearing: 92.0,
        accuracyMeters: 4.0,
        timestamp: now.add(const Duration(seconds: 1)),
      );

      locationService.emitPosition(pos1);
      locationService.emitPosition(pos2);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(positions.length, equals(2));
      expect(positions[0].speedKmh, equals(60.0));
      expect(positions[1].bearing, equals(92.0));

      await sub.cancel();
    });

    test('LocationPermissionStatus enum deve conter os valores corretos', () {
      expect(LocationPermissionStatus.values, contains(LocationPermissionStatus.denied));
      expect(LocationPermissionStatus.values, contains(LocationPermissionStatus.deniedForever));
      expect(LocationPermissionStatus.values, contains(LocationPermissionStatus.whileInUse));
      expect(LocationPermissionStatus.values, contains(LocationPermissionStatus.always));
    });
  });

  group('GeolocatorLocationService Hardware Wrapper Tests', () {
    late MockGeolocatorPlatform mockPlatform;
    late GeolocatorLocationService geolocatorService;

    setUp(() {
      mockPlatform = MockGeolocatorPlatform();
      geolocatorService = GeolocatorLocationService(platform: mockPlatform);
    });

    test('Construtor padrão sem platform deve instanciar com sucesso', () {
      final defaultService = GeolocatorLocationService();
      expect(defaultService, isNotNull);
    });

    test('isLocationServiceEnabled deve delegar à plataforma', () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      expect(await geolocatorService.isLocationServiceEnabled(), isTrue);

      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => false);
      expect(await geolocatorService.isLocationServiceEnabled(), isFalse);

      when(() => mockPlatform.isLocationServiceEnabled())
          .thenThrow(Exception('Platform error'));
      expect(await geolocatorService.isLocationServiceEnabled(), isFalse);
    });

    test('checkPermission e requestPermission devem mapear estados de permissão', () async {
      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.always);
      expect(await geolocatorService.checkPermission(),
          equals(LocationPermissionStatus.always));

      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);
      expect(await geolocatorService.checkPermission(),
          equals(LocationPermissionStatus.whileInUse));

      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.deniedForever);
      expect(await geolocatorService.checkPermission(),
          equals(LocationPermissionStatus.deniedForever));

      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.denied);
      expect(await geolocatorService.checkPermission(),
          equals(LocationPermissionStatus.denied));

      when(() => mockPlatform.requestPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);
      expect(await geolocatorService.requestPermission(),
          equals(LocationPermissionStatus.whileInUse));

      when(() => mockPlatform.checkPermission())
          .thenThrow(Exception('Check failed'));
      expect(await geolocatorService.checkPermission(),
          equals(LocationPermissionStatus.denied));

      when(() => mockPlatform.requestPermission())
          .thenThrow(Exception('Request failed'));
      expect(await geolocatorService.requestPermission(),
          equals(LocationPermissionStatus.denied));
    });

    test('getPositionStream deve mapear Position para VehiclePosition com m/s para km/h', () async {
      final positionStreamController = StreamController<Position>();
      when(() => mockPlatform.getPositionStream(locationSettings: any(named: 'locationSettings')))
          .thenAnswer((_) => positionStreamController.stream);

      final stream = geolocatorService.getPositionStream();
      final captured = <VehiclePosition>[];
      final sub = stream.listen(captured.add);

      final pos = Position(
        latitude: -23.5505,
        longitude: -46.6333,
        timestamp: DateTime(2026, 10, 30, 10, 0),
        accuracy: 4.5,
        altitude: 800.0,
        altitudeAccuracy: 1.0,
        heading: 180.0,
        headingAccuracy: 1.0,
        speed: 20.0, // 20 m/s = 72 km/h
        speedAccuracy: 0.5,
      );

      positionStreamController.add(pos);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(captured.length, equals(1));
      expect(captured.first.latitude, equals(-23.5505));
      expect(captured.first.longitude, equals(-46.6333));
      expect(captured.first.speedKmh, closeTo(72.0, 0.01));
      expect(captured.first.bearing, equals(180.0));
      expect(captured.first.accuracyMeters, equals(4.5));

      await sub.cancel();
      await positionStreamController.close();
    });
  });
}
