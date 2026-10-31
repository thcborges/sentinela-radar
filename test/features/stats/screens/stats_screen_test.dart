import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/features/stats/bloc/stats_cubit.dart';
import 'package:sentinela/features/stats/models/passage_record.dart';
import 'package:sentinela/features/stats/screens/stats_screen.dart';

class MockStatsCubit extends MockCubit<StatsState> implements StatsCubit {}

void main() {
  late MockStatsCubit mockStatsCubit;

  setUp(() {
    mockStatsCubit = MockStatsCubit();
  });

  group('StatsScreen Widget (Material Design 3 Dark HUD)', () {
    testWidgets('deve renderizar tela de estatísticas vazia com badge de privacidade', (tester) async {
      when(() => mockStatsCubit.state).thenReturn(
        const StatsState(
          isLoading: false,
          summary: StatsSummary(totalPassages: 0, overSpeedPassages: 0),
          recentPassages: [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<StatsCubit>.value(
            value: mockStatsCubit,
            child: const StatsScreen(),
          ),
        ),
      );

      expect(find.text('Estatísticas de Condução'), findsOneWidget);
      expect(find.text('Privacidade Absoluta (100% Offline)'), findsOneWidget);
      expect(find.text('Nenhuma passagem registrada ainda.'), findsOneWidget);
      expect(find.text('100.0%'), findsOneWidget); // Taxa de conformidade inicial
    });

    testWidgets('deve renderizar métricas consolidadas e itens na lista de passagens', (tester) async {
      final now = DateTime(2026, 10, 30, 14, 25);
      final passages = [
        PassageRecord(
          id: 1,
          poiId: 10,
          poiType: PoiType.fixedRadar,
          vehicleSpeedKmh: 58,
          speedLimit: 60,
          timestamp: now,
          isOverSpeed: false,
          roadName: 'Av. Paulista',
        ),
        PassageRecord(
          id: 2,
          poiId: 20,
          poiType: PoiType.trafficLightRadar,
          vehicleSpeedKmh: 68,
          speedLimit: 50,
          timestamp: now.subtract(const Duration(minutes: 10)),
          isOverSpeed: true,
          roadName: 'Av. Brigadeiro',
        ),
      ];

      when(() => mockStatsCubit.state).thenReturn(
        StatsState(
          isLoading: false,
          summary: const StatsSummary(totalPassages: 2, overSpeedPassages: 1),
          recentPassages: passages,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<StatsCubit>.value(
            value: mockStatsCubit,
            child: const StatsScreen(),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget); // Total
      expect(find.text('1'), findsOneWidget); // Excessos
      expect(find.text('50.0%'), findsOneWidget); // 1 de 2 = 50%
      expect(find.text('Av. Paulista'), findsOneWidget);
      expect(find.text('Av. Brigadeiro'), findsOneWidget);
      expect(find.text('58 km/h'), findsOneWidget);
      expect(find.text('68 km/h'), findsOneWidget);
    });

    testWidgets('deve exibir diálogo de confirmação e chamar clearHistory ao confirmar limpeza', (tester) async {
      when(() => mockStatsCubit.state).thenReturn(
        const StatsState(
          isLoading: false,
          summary: StatsSummary(totalPassages: 5, overSpeedPassages: 0),
          recentPassages: [],
        ),
      );
      when(() => mockStatsCubit.clearHistory()).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<StatsCubit>.value(
            value: mockStatsCubit,
            child: const StatsScreen(),
          ),
        ),
      );

      final deleteButton = find.byIcon(Icons.delete_sweep_rounded);
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.text('Limpar Histórico Local?'), findsOneWidget);
      final confirmButton = find.text('LIMPAR DADOS');
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      verify(() => mockStatsCubit.clearHistory()).called(1);
    });

    testWidgets('deve renderizar card de pedágios e taxas individuais quando houver custos de pedágio', (tester) async {
      final passages = [
        PassageRecord(
          id: 1,
          poiId: 101,
          poiType: PoiType.freeFlowToll,
          vehicleSpeedKmh: 90,
          timestamp: DateTime(2026, 10, 30, 10, 0),
          isOverSpeed: false,
          roadName: 'SP-099 Free Flow',
          tollFee: 4.20,
        ),
      ];

      when(() => mockStatsCubit.state).thenReturn(
        StatsState(
          isLoading: false,
          summary: const StatsSummary(totalPassages: 1, overSpeedPassages: 0, totalTollCost: 4.20),
          recentPassages: passages,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<StatsCubit>.value(
            value: mockStatsCubit,
            child: const StatsScreen(),
          ),
        ),
      );

      expect(find.byKey(const Key('stats_toll_card')), findsOneWidget);
      expect(find.text('Pedágios & Free Flow Estimados'), findsOneWidget);
      expect(find.text('R\$ 4,20'), findsOneWidget);
      expect(find.text('Tarifa: R\$ 4,20'), findsOneWidget);
    });

    testWidgets('deve disparar exportacao de GPX e KML pelo menu da AppBar', (tester) async {
      final passages = [
        PassageRecord(
          id: 1,
          poiId: 10,
          poiType: PoiType.fixedRadar,
          vehicleSpeedKmh: 58,
          speedLimit: 60,
          timestamp: DateTime(2026, 10, 30, 10, 0),
          isOverSpeed: false,
          roadName: 'Av. Paulista',
          latitude: -23.56,
          longitude: -46.65,
        ),
      ];

      when(() => mockStatsCubit.state).thenReturn(
        StatsState(
          isLoading: false,
          summary: const StatsSummary(totalPassages: 1, overSpeedPassages: 0),
          recentPassages: passages,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: BlocProvider<StatsCubit>.value(
            value: mockStatsCubit,
            child: const StatsScreen(),
          ),
        ),
      );

      // Abrir menu de exportação
      final menuBtn = find.byKey(const Key('stats_export_menu_button'));
      expect(menuBtn, findsOneWidget);

      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      expect(find.text('Exportar GPX (1.1)'), findsOneWidget);
      expect(find.text('Exportar KML (2.2)'), findsOneWidget);

      // Tocar em Exportar GPX
      await tester.tap(find.text('Exportar GPX (1.1)'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats_export_gpx_snackbar')), findsOneWidget);
      expect(find.text('GPX exportado com sucesso (1 waypoints)'), findsOneWidget);

      // Abrir menu novamente e testar KML
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exportar KML (2.2)'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats_export_kml_snackbar')), findsOneWidget);
      expect(find.text('KML exportado com sucesso (1 waypoints)'), findsOneWidget);
    });
  });
}
