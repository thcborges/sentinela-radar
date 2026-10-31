import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/dashboard/widgets/alert_banner_m3.dart';
import 'package:sentinela/features/dashboard/widgets/sonar_radar_m3.dart';
import 'package:sentinela/features/dashboard/widgets/speedometer_m3.dart';

void main() {
  group('Accessibility & Semantics M3 Tests (BDD - TalkBack & VoiceOver)', () {
    testWidgets('SpeedometerM3 deve incluir Semantics com velocidade atual e limite', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpeedometerM3(
              speedKmh: 82.0,
              speedLimit: 80,
              alertStatus: AlertStatus.overSpeed,
            ),
          ),
        ),
      );

      final speedometerSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Velocímetro' &&
            widget.properties.value == '82 km/h',
      );
      expect(speedometerSemantics, findsOneWidget);

      final speedLimitSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Velocidade máxima permitida' &&
            widget.properties.value == '80 km/h',
      );
      expect(speedLimitSemantics, findsOneWidget);
    });

    testWidgets('SonarRadarM3 deve incluir Semantics descritivo com contagem de POIs', (tester) async {
      final sonarPois = [
        const SonarPoiItem(
          poi: PoiPoint(id: 1, latitude: -23.5, longitude: -46.6, type: PoiType.fixedRadar, speedLimit: 60),
          distanceMeters: 300,
          relativeAngleDeg: 10,
        ),
        const SonarPoiItem(
          poi: PoiPoint(id: 2, latitude: -23.5, longitude: -46.6, type: PoiType.physicalSpeedBump),
          distanceMeters: 150,
          relativeAngleDeg: -5,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SonarRadarM3(
              items: sonarPois,
            ),
          ),
        ),
      );

      final sonarSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Sonar frontal de radar' &&
            widget.properties.value == '2 pontos detectados à frente no radar',
      );
      expect(sonarSemantics, findsOneWidget);
    });

    testWidgets('AlertBannerM3 deve incluir liveRegion para leitor de tela quando houver alerta ativo', (tester) async {
      const activeAlert = ActiveAlert(
        poi: PoiPoint(id: 1, latitude: -23.5, longitude: -46.6, type: PoiType.fixedRadar, speedLimit: 60),
        distanceMeters: 280,
        currentSpeedKmh: 75,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 180,
        relativeBearing: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlertBannerM3(
              activeAlert: activeAlert,
              status: AlertStatus.overSpeed,
            ),
          ),
        ),
      );

      final alertSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label != null &&
            widget.properties.label!.contains('Radar Fixo'),
      );
      expect(alertSemantics, findsOneWidget);
    });

    testWidgets('SpeedometerM3 deve suportar isHighContrast com contraste visual reforçado', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpeedometerM3(
              speedKmh: 60.0,
              speedLimit: 80,
              isHighContrast: true,
            ),
          ),
        ),
      );

      expect(find.byType(SpeedometerM3), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
    });
  });
}
