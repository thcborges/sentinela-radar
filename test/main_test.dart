import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sentinela/core/location/location_service_interface.dart';
import 'package:sentinela/core/network/connectivity_checker.dart';
import 'package:sentinela/features/overlay/widgets/floating_overlay_widget.dart';
import 'package:sentinela/main.dart' as app;

class MockLocationService extends Mock implements LocationService {}
class MockConnectivityChecker extends Mock implements NetworkConnectivityChecker {}

void main() {
  testWidgets('SentinelaApp deve inicializar com MaterialApp e tema Material 3', (tester) async {
    await tester.pumpWidget(const app.SentinelaApp(useInMemoryDb: true));
    await tester.pump();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
    expect(materialApp.theme?.brightness, equals(Brightness.dark));
    expect(find.text('SENTINELA'), findsOneWidget);
    expect(find.byKey(const Key('dashboard_diagnostics_button')), findsOneWidget);
  });

  testWidgets('SentinelaApp deve abrir modal de diagnóstico ao clicar no botão da AppBar', (tester) async {
    final mockLocation = MockLocationService();
    final mockConnectivity = MockConnectivityChecker();

    when(() => mockLocation.isLocationServiceEnabled()).thenAnswer((_) async => true);
    when(() => mockLocation.checkPermission()).thenAnswer((_) async => LocationPermissionStatus.whileInUse);
    when(() => mockLocation.getPositionStream(
          distanceFilterMeters: any(named: 'distanceFilterMeters'),
          intervalMs: any(named: 'intervalMs'),
        )).thenAnswer((_) => const Stream.empty());
    when(() => mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(() => mockConnectivity.isWifiConnected()).thenAnswer((_) async => true);

    await tester.pumpWidget(app.SentinelaApp(
      useInMemoryDb: true,
      locationService: mockLocation,
      connectivityChecker: mockConnectivity,
    ));
    await tester.pump();

    final diagBtn = find.byKey(const Key('dashboard_diagnostics_button'));
    expect(diagBtn, findsOneWidget);

    await tester.tap(diagBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('GPS Hardware'), findsOneWidget);
    expect(find.text('Base SQLite R*Tree'), findsOneWidget);
  });

  testWidgets('overlayMain deve ser executável e instanciar FloatingOverlayWidget', (tester) async {
    // Testa a execução do entry point nativo
    app.overlayMain();
    await tester.pump();

    expect(find.byType(FloatingOverlayWidget), findsOneWidget);
  });

  testWidgets('SentinelaApp deve suportar injeção de database customizado', (tester) async {
    final customDb = sqlite3.openInMemory();
    await tester.pumpWidget(app.SentinelaApp(database: customDb));
    await tester.pump();

    expect(find.text('SENTINELA'), findsOneWidget);
  });

  testWidgets('SentinelaApp deve inicializar com banco de arquivo em disco', (tester) async {
    final mockLocation = MockLocationService();
    final mockConnectivity = MockConnectivityChecker();
    when(() => mockLocation.getPositionStream(
          distanceFilterMeters: any(named: 'distanceFilterMeters'),
          intervalMs: any(named: 'intervalMs'),
        )).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(app.SentinelaApp(
      locationService: mockLocation,
      connectivityChecker: mockConnectivity,
    ));
    await tester.pump();

    expect(find.text('SENTINELA'), findsOneWidget);

    final testDb = File('sentinela_brasil.db');
    if (testDb.existsSync()) {
      try {
        testDb.deleteSync();
      } catch (_) {}
    }
  });
}
