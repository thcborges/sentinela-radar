import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/features/overlay/widgets/floating_overlay_widget.dart';

void main() {
  group('FloatingOverlayWidget (Miniatura Flutuante M3)', () {
    testWidgets('deve exibir velocidade atual e estado neutro quando não houver alerta ativo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: const Scaffold(
            body: FloatingOverlayWidget(
              currentSpeedKmh: 45.0,
              activeAlert: null,
            ),
          ),
        ),
      );

      expect(find.text('45'), findsOneWidget);
      expect(find.text('km/h'), findsOneWidget);
      expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
    });

    testWidgets('deve exibir distância regressiva, limite e ícone ao aproximar de radar fixo', (tester) async {
      const poi = PoiPoint(
        id: 1,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.fixedRadar,
        speedLimit: 60,
      );

      const alert = ActiveAlert(
        poi: poi,
        distanceMeters: 280,
        currentSpeedKmh: 58,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: const Scaffold(
            body: FloatingOverlayWidget(
              currentSpeedKmh: 58.0,
              activeAlert: alert,
            ),
          ),
        ),
      );

      expect(find.text('58'), findsOneWidget);
      expect(find.text('280m'), findsOneWidget);
      expect(find.text('60'), findsOneWidget); // Limite da via
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    });

    testWidgets('deve disparar callbacks de clique e fechamento', (tester) async {
      bool tapped = false;
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: Scaffold(
            body: FloatingOverlayWidget(
              currentSpeedKmh: 60.0,
              activeAlert: null,
              onTap: () => tapped = true,
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FloatingOverlayWidget));
      expect(tapped, isTrue);

      final closeButton = find.byIcon(Icons.close_rounded);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      expect(closed, isTrue);
    });

    testWidgets('deve formatar distância quilométrica e renderizar ícones para pedágio e outros tipos', (tester) async {
      const poiToll = PoiPoint(
        id: 99,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.tollBooth,
      );

      const alertToll = ActiveAlert(
        poi: poiToll,
        distanceMeters: 1500, // >= 1000m -> "1.5km"
        currentSpeedKmh: 90,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: const Scaffold(
            body: FloatingOverlayWidget(
              currentSpeedKmh: 90.0,
              activeAlert: alertToll,
            ),
          ),
        ),
      );

      expect(find.text('1.5km'), findsOneWidget);
      expect(find.byIcon(Icons.toll_rounded), findsOneWidget);

      // Lombada
      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: const Scaffold(
            body: FloatingOverlayWidget(
              currentSpeedKmh: 40.0,
              activeAlert: ActiveAlert(
                poi: PoiPoint(id: 101, latitude: 0, longitude: 0, type: PoiType.electronicSpeedBump),
                distanceMeters: 80,
                currentSpeedKmh: 40,
                status: AlertStatus.alerting,
                isOverSpeed: false,
                targetBearing: 0,
                relativeBearing: 0,
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.waves_rounded), findsOneWidget);

      // Polícia rodoviária
      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: const Scaffold(
            body: FloatingOverlayWidget(
              currentSpeedKmh: 70.0,
              activeAlert: ActiveAlert(
                poi: PoiPoint(id: 102, latitude: 0, longitude: 0, type: PoiType.highwayPatrol),
                distanceMeters: 400,
                currentSpeedKmh: 70,
                status: AlertStatus.alerting,
                isOverSpeed: false,
                targetBearing: 0,
                relativeBearing: 0,
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.local_police_rounded), findsOneWidget);
    });

    testWidgets('deve renderizar botão de marcação rápida e disparar onQuickReport quando fornecido', (tester) async {
      bool quickReported = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: Scaffold(
            body: FloatingOverlayWidget(
              currentSpeedKmh: 50.0,
              onQuickReport: () => quickReported = true,
            ),
          ),
        ),
      );

      final button = find.byKey(const Key('overlay_quick_report_button'));
      expect(button, findsOneWidget);

      await tester.tap(button);
      expect(quickReported, isTrue);
    });
  });
}
