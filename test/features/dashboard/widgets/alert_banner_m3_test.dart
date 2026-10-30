import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/features/dashboard/widgets/alert_banner_m3.dart';

void main() {
  group('AlertBannerM3 Widget (Material Design 3 Dark HUD)', () {
    testWidgets('deve exibir mensagem de via segura quando não houver alerta ativo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: const Scaffold(
            body: AlertBannerM3(
              activeAlert: null,
              status: AlertStatus.idle,
            ),
          ),
        ),
      );

      expect(find.text('Via Segura • Monitoramento Ativo'), findsOneWidget);
      expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    });

    testWidgets('deve exibir detalhes de aproximação de radar com distância e nome da via', (tester) async {
      const poi = PoiPoint(
        id: 1,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.fixedRadar,
        speedLimit: 60,
        roadName: 'Av. Paulista',
      );

      const alert = ActiveAlert(
        poi: poi,
        distanceMeters: 380,
        currentSpeedKmh: 55,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 90,
        relativeBearing: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: const Scaffold(
            body: AlertBannerM3(
              activeAlert: alert,
              status: AlertStatus.alerting,
            ),
          ),
        ),
      );

      expect(find.text('Radar Fixo'), findsOneWidget);
      expect(find.text('380 m'), findsOneWidget);
      expect(find.text('Av. Paulista'), findsOneWidget);
    });

    testWidgets('deve destacar aviso crítico quando status for overSpeed', (tester) async {
      const poi = PoiPoint(
        id: 2,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.trafficLightRadar,
        speedLimit: 50,
        roadName: 'Rua da Consolação',
      );

      const alert = ActiveAlert(
        poi: poi,
        distanceMeters: 220,
        currentSpeedKmh: 68,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 180,
        relativeBearing: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: const Scaffold(
            body: AlertBannerM3(
              activeAlert: alert,
              status: AlertStatus.overSpeed,
            ),
          ),
        ),
      );

      expect(find.text('REDUZA A VELOCIDADE'), findsOneWidget);
      expect(find.text('Semáforo c/ Radar'), findsOneWidget);
      expect(find.text('220 m'), findsOneWidget);
    });
  });
}
