import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/features/dashboard/widgets/speedometer_m3.dart';

void main() {
  group('SpeedometerM3 Widget (Material Design 3 Dark HUD)', () {
    testWidgets('deve exibir velocidade atual formatada e unidade km/h', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: const Scaffold(
            body: SpeedometerM3(
              speedKmh: 75.4,
              speedLimit: 60,
              alertStatus: AlertStatus.idle,
              isGpsFixValid: true,
            ),
          ),
        ),
      );

      expect(find.text('75'), findsOneWidget);
      expect(find.text('km/h'), findsOneWidget);
      expect(find.text('60'), findsOneWidget); // Placa de velocidade da via
    });

    testWidgets('deve exibir aviso de busca de sinal quando isGpsFixValid for falso', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: const Scaffold(
            body: SpeedometerM3(
              speedKmh: 0.0,
              speedLimit: null,
              alertStatus: AlertStatus.idle,
              isGpsFixValid: false,
            ),
          ),
        ),
      );

      expect(find.text('Buscando GPS...'), findsOneWidget);
      expect(find.byIcon(Icons.gps_not_fixed_rounded), findsOneWidget);
    });

    testWidgets('deve renderizar anel de alerta com cor crítica quando em excesso de velocidade', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: const Scaffold(
            body: SpeedometerM3(
              speedKmh: 95.0,
              speedLimit: 80,
              alertStatus: AlertStatus.overSpeed,
              isGpsFixValid: true,
            ),
          ),
        ),
      );

      expect(find.text('95'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      final customPaint = tester.widget<CustomPaint>(
        find.byKey(const Key('speedometer_ring_painter')),
      );
      expect(customPaint.painter, isNotNull);
    });
  });
}
