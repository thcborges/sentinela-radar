import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/dashboard/widgets/alert_banner_m3.dart';
import 'package:sentinela/features/dashboard/widgets/sonar_radar_m3.dart';
import 'package:sentinela/features/dashboard/widgets/speedometer_m3.dart';
import 'package:sentinela/features/settings/screens/settings_screen.dart';

/// Tela Principal do Motorista (Dark HUD / Material Design 3)
class DashboardScreen extends StatelessWidget {
  final PoiSyncService syncService;

  const DashboardScreen({
    super.key,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SENTINELA',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Configurações',
            onPressed: () {
              final cubit = context.read<DashboardCubit>();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    syncService: syncService,
                    dashboardCubit: cubit,
                    initialStats: {
                      'radares': cubit.state.totalPoisCount,
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          final int? speedLimit = state.activeAlert?.poi.speedLimit;

          return SafeArea(
            child: OrientationBuilder(
              builder: (context, orientation) {
                final isLandscape = orientation == Orientation.landscape;

                if (isLandscape) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // Coluna da esquerda: Velocímetro e Alerta
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              Expanded(
                                child: SpeedometerM3(
                                  key: const Key('dashboard_speedometer'),
                                  speedKmh: state.currentSpeedKmh,
                                  speedLimit: speedLimit,
                                  alertStatus: state.alertStatus,
                                  isGpsFixValid: state.isGpsFixValid,
                                ),
                              ),
                              const SizedBox(height: 8),
                              AlertBannerM3(
                                key: const Key('dashboard_alert_banner'),
                                activeAlert: state.activeAlert,
                                status: state.alertStatus,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Coluna da direita: Sonar Radar Frontal
                        Expanded(
                          flex: 1,
                          child: SonarRadarM3(
                            key: const Key('dashboard_sonar'),
                            items: state.nearbySonarPois,
                            maxRangeMeters: 1000,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Modo Portrait (Padrão)
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      // Nome da Via / Logradouro Atual
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: SentinelaTheme.surfaceContainerDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF262626), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.navigation_rounded,
                              size: 14,
                              color: SentinelaTheme.alertNormal,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                state.roadName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFB0B0B0),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Card Central de Alerta Ativo
                      AlertBannerM3(
                        key: const Key('dashboard_alert_banner'),
                        activeAlert: state.activeAlert,
                        status: state.alertStatus,
                      ),

                      const SizedBox(height: 12),

                      // Velocímetro Central
                      Expanded(
                        flex: 6,
                        child: SpeedometerM3(
                          key: const Key('dashboard_speedometer'),
                          speedKmh: state.currentSpeedKmh,
                          speedLimit: speedLimit,
                          alertStatus: state.alertStatus,
                          isGpsFixValid: state.isGpsFixValid,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Sonar Circular Frontal
                      Expanded(
                        flex: 5,
                        child: SonarRadarM3(
                          key: const Key('dashboard_sonar'),
                          items: state.nearbySonarPois,
                          maxRangeMeters: 1000,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
