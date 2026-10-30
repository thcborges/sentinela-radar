import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/features/overlay/services/overlay_service.dart';

class MockOverlayPlatformAdapter extends Mock implements OverlayPlatformAdapter {}

void main() {
  late MockOverlayPlatformAdapter mockAdapter;
  late OverlayService service;

  setUp(() {
    mockAdapter = MockOverlayPlatformAdapter();
    service = OverlayService(adapter: mockAdapter);
  });

  group('OverlayService (Gerenciamento da Janela Flutuante / PiP)', () {
    test('deve solicitar permissão e iniciar overlay com sucesso se autorizado', () async {
      when(() => mockAdapter.isPermissionGranted()).thenAnswer((_) async => false);
      when(() => mockAdapter.requestPermission()).thenAnswer((_) async => true);
      when(() => mockAdapter.showOverlay(height: any(named: 'height'), width: any(named: 'width')))
          .thenAnswer((_) async => true);

      final result = await service.startOverlay();

      expect(result, isTrue);
      expect(service.isOverlayOpen, isTrue);
      verify(() => mockAdapter.requestPermission()).called(1);
      verify(() => mockAdapter.showOverlay(height: any(named: 'height'), width: any(named: 'width'))).called(1);
    });

    test('não deve iniciar overlay se permissão for negada pelo usuário', () async {
      when(() => mockAdapter.isPermissionGranted()).thenAnswer((_) async => false);
      when(() => mockAdapter.requestPermission()).thenAnswer((_) async => false);

      final result = await service.startOverlay();

      expect(result, isFalse);
      expect(service.isOverlayOpen, isFalse);
      verifyNever(() => mockAdapter.showOverlay(height: any(named: 'height'), width: any(named: 'width')));
    });

    test('deve fechar overlay e atualizar estado interno', () async {
      when(() => mockAdapter.isPermissionGranted()).thenAnswer((_) async => true);
      when(() => mockAdapter.showOverlay(height: any(named: 'height'), width: any(named: 'width')))
          .thenAnswer((_) async => true);
      when(() => mockAdapter.closeOverlay()).thenAnswer((_) async => true);

      await service.startOverlay();
      expect(service.isOverlayOpen, isTrue);

      final stopped = await service.stopOverlay();
      expect(stopped, isTrue);
      expect(service.isOverlayOpen, isFalse);
      verify(() => mockAdapter.closeOverlay()).called(1);
    });

    test('deve despachar dados atualizados de telemetria e alerta quando overlay estiver aberto', () async {
      when(() => mockAdapter.isPermissionGranted()).thenAnswer((_) async => true);
      when(() => mockAdapter.showOverlay(height: any(named: 'height'), width: any(named: 'width')))
          .thenAnswer((_) async => true);
      when(() => mockAdapter.shareData(any())).thenAnswer((_) async {});

      await service.startOverlay();

      const poi = PoiPoint(
        id: 1,
        latitude: -23.5,
        longitude: -46.6,
        type: PoiType.fixedRadar,
        speedLimit: 80,
      );

      const alert = ActiveAlert(
        poi: poi,
        distanceMeters: 200,
        currentSpeedKmh: 95,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 180,
        relativeBearing: 0,
      );

      await service.updateOverlayData(speedKmh: 95, alert: alert);

      verify(() => mockAdapter.shareData({
        'speed': 95.0,
        'hasAlert': true,
        'isOverSpeed': true,
        'distanceMeters': 200.0,
        'speedLimit': 80,
        'poiType': 'fixedRadar',
      })).called(1);
    });

    test('não deve despachar dados quando overlay estiver fechado', () async {
      await service.updateOverlayData(speedKmh: 50, alert: null);
      verifyNever(() => mockAdapter.shareData(any()));
    });

    test('deve verificar permissão e tratar falha ao parar overlay', () async {
      when(() => mockAdapter.isPermissionGranted()).thenAnswer((_) async => true);
      final hasPerm = await service.checkPermission();
      expect(hasPerm, isTrue);

      when(() => mockAdapter.closeOverlay()).thenAnswer((_) async => false);
      final stopped = await service.stopOverlay();
      expect(stopped, isFalse);
    });
  });
}
