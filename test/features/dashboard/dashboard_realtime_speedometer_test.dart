import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/engine/adaptive_gps_sampler.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/core/location/geolocator_location_service.dart';
import 'package:sentinela/core/location/location_service_interface.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/dashboard/screens/dashboard_screen.dart';
import 'package:geolocator/geolocator.dart';

class MockPoiRepository extends Mock implements PoiRepository {}
class MockAlertMachine extends Mock implements AlertMachine {}
class MockPoiSyncService extends Mock implements PoiSyncService {}
class MockGeolocatorPlatform extends Mock implements GeolocatorPlatform {}

class RecordingLocationService implements LocationService {
  @override
  int get defaultIntervalMs => 250;

  int? lastDistanceFilterMeters;
  int? lastIntervalMs;
  final StreamController<VehiclePosition> controller =
      StreamController<VehiclePosition>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.always;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.always;

  @override
  Stream<VehiclePosition> getPositionStream({
    int distanceFilterMeters = 0,
    int intervalMs = 250,
  }) {
    lastDistanceFilterMeters = distanceFilterMeters;
    lastIntervalMs = intervalMs;
    return controller.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const AlertPreferences());
  });

  group('Speedometer Near Real-Time Update Tests (BDD/TDD)', () {
    late MockPoiRepository mockRepo;
    late MockAlertMachine mockAlertMachine;
    late MockPoiSyncService mockSyncService;

    setUp(() {
      mockRepo = MockPoiRepository();
      mockAlertMachine = MockAlertMachine();
      mockSyncService = MockPoiSyncService();
      when(() => mockAlertMachine.state)
          .thenReturn(const AlertState(status: AlertStatus.idle));
      when(() => mockAlertMachine.preferences)
          .thenReturn(const AlertPreferences());
      when(() => mockSyncService.progressStream)
          .thenAnswer((_) => const Stream.empty());
    });

    test('GeolocatorLocationService deve usar intervalMs <= 250 e distanceFilter <= 0 por padrao para tempo quase instantaneo', () {
      final mockPlatform = MockGeolocatorPlatform();
      final service = GeolocatorLocationService(platform: mockPlatform);

      when(() => mockPlatform.getPositionStream(
            locationSettings: any(named: 'locationSettings'),
          )).thenAnswer((_) => const Stream.empty());

      service.getPositionStream();

      final captured = verify(() => mockPlatform.getPositionStream(
            locationSettings: captureAny(named: 'locationSettings'),
          )).captured.single as LocationSettings;

      expect(captured.distanceFilter, equals(0),
          reason: 'distanceFilter deve ser 0 para permitir atualizações de velocímetro em tempo quase real sem deslocamento mínimo');
      expect(captured.accuracy, equals(LocationAccuracy.bestForNavigation));
      expect(service.defaultIntervalMs, lessThanOrEqualTo(250),
          reason: 'intervalMs padrão deve ser <= 250ms (4 Hz) para tempo quase instantâneo');
    });

    test('AdaptiveGpsSampler deve manter intervalo recomendado <= 1000ms (1 segundo ou menos) mesmo em modo estacionario', () {
      final sampler = AdaptiveGpsSampler(
        stationaryThreshold: const Duration(seconds: 10),
      );

      final t0 = DateTime(2026, 11, 1, 10, 0, 0);
      sampler.updateSpeed(0.0, timestamp: t0);
      sampler.updateSpeed(0.0, timestamp: t0.add(const Duration(seconds: 15)));

      expect(sampler.isStationary, isTrue);
      expect(sampler.recommendedIntervalMs, lessThanOrEqualTo(1000),
          reason: 'Intervalo em modo estacionário não deve exceder 1 segundo para evitar atraso ao arrancar o veículo');
      expect(sampler.recommendedDistanceFilterMeters, lessThanOrEqualTo(2),
          reason: 'Filtro de deslocamento em repouso deve ser reduzido para detectar retomada de marcha imediatamente');
    });

    test('DashboardCubit deve emitir atualizacao imediata de velocidade sem aguardar I/O de banco de dados', () async {
      final completer = Completer<List<PoiPoint>>();
      when(() => mockRepo.findNearbyPois(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          )).thenAnswer((_) => completer.future);

      final cubit = DashboardCubit(
        repository: mockRepo,
        alertMachine: mockAlertMachine,
      );

      final statesEmitted = <double>[];
      final sub = cubit.stream.map((s) => s.currentSpeedKmh).listen(statesEmitted.add);

      final pos = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 85.0,
        bearing: 45.0,
        accuracyMeters: 5.0,
        timestamp: DateTime(2026, 11, 1, 10, 0, 0),
      );

      // Inicia a atualização de localização (sem completar a busca no banco)
      final updateFuture = cubit.onLocationUpdated(pos);

      // Aguarda microtasks
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Velocidade deve ter sido atualizada no estado quase em tempo real
      expect(cubit.state.currentSpeedKmh, equals(85.0),
          reason: 'Velocímetro deve refletir a nova velocidade de 85 km/h sem aguardar o retorno da query SQLite');

      // Agora completa a query SQLite
      completer.complete([]);
      await updateFuture;

      expect(cubit.state.currentSpeedKmh, equals(85.0));

      await sub.cancel();
      await cubit.close();
    });

    testWidgets('DashboardScreen deve configurar getPositionStream com intervalMs <= 250 e distanceFilter 0', (tester) async {
      final recordingLocation = RecordingLocationService();
      when(() => mockRepo.findNearbyPois(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          )).thenAnswer((_) async => []);

      final cubit = DashboardCubit(
        repository: mockRepo,
        alertMachine: mockAlertMachine,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<DashboardCubit>.value(
            value: cubit,
            child: DashboardScreen(
              syncService: mockSyncService,
              locationService: recordingLocation,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(recordingLocation.lastDistanceFilterMeters, equals(0),
          reason: 'DashboardScreen deve requisitar distanceFilterMeters: 0 para tempo quase real');
      expect(recordingLocation.lastIntervalMs, lessThanOrEqualTo(250),
          reason: 'DashboardScreen deve requisitar intervalMs <= 250ms para tempo quase instantâneo');

      cubit.close();
    });
  });
}
