import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentinela/core/diagnostics/system_diagnostics.dart';
import 'package:sentinela/core/hardware/wakelock_manager.dart';
import 'package:sentinela/core/location/location_service_interface.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/dashboard/widgets/alert_banner_m3.dart';
import 'package:sentinela/features/dashboard/widgets/sonar_radar_m3.dart';
import 'package:sentinela/features/dashboard/widgets/speedometer_m3.dart';
import 'package:sentinela/features/overlay/services/overlay_service.dart';
import 'package:sentinela/features/settings/screens/settings_screen.dart';
import 'package:sentinela/features/stats/bloc/stats_cubit.dart';
import 'package:sentinela/features/stats/screens/stats_screen.dart';

/// Tela Principal do Motorista (Dark HUD / Material Design 3)
class DashboardScreen extends StatefulWidget {
  final PoiSyncService syncService;
  final StatsCubit? statsCubit;
  final WakelockManager? wakelockManager;
  final LocationService? locationService;
  final OverlayService? overlayService;
  final SystemDiagnosticsService? diagnosticsService;

  const DashboardScreen({
    super.key,
    required this.syncService,
    this.statsCubit,
    this.wakelockManager,
    this.locationService,
    this.overlayService,
    this.diagnosticsService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<VehiclePosition>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    widget.wakelockManager?.enable();
    if (widget.locationService != null) {
      _locationSubscription = widget.locationService!
          .getPositionStream()
          .listen((pos) {
        if (mounted) {
          context.read<DashboardCubit>().onLocationUpdated(pos);
        }
      });
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    widget.wakelockManager?.disable();
    super.dispose();
  }

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
          if (widget.statsCubit != null)
            IconButton(
              icon: const Icon(Icons.analytics_rounded),
              tooltip: 'Estatísticas',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BlocProvider.value(
                      value: widget.statsCubit!,
                      child: const StatsScreen(),
                    ),
                  ),
                );
              },
            ),
          if (widget.diagnosticsService != null)
            IconButton(
              key: const Key('dashboard_diagnostics_button'),
              icon: const Icon(Icons.health_and_safety_rounded),
              tooltip: 'Diagnóstico do Sistema',
              onPressed: () => _showDiagnosticsModal(context),
            ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Configurações',
            onPressed: () {
              final cubit = context.read<DashboardCubit>();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    syncService: widget.syncService,
                    dashboardCubit: cubit,
                    wakelockManager: widget.wakelockManager,
                    overlayService: widget.overlayService,
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

  void _showDiagnosticsModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SentinelaTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FutureBuilder<DiagnosticReport>(
          future: widget.diagnosticsService!.runDiagnostics(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 250,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final report = snapshot.data;
            if (report == null) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text('Erro ao obter diagnóstico.')),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        report.isReadyForNavigation
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        color: report.isReadyForNavigation
                            ? SentinelaTheme.alertNormal
                            : SentinelaTheme.alertWarning,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          report.summaryMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF333333), height: 32),
                  _buildDiagnosticRow(
                    label: 'GPS Hardware',
                    status: report.isGpsHardwareEnabled ? 'Ativo' : 'Desativado',
                    isOk: report.isGpsHardwareEnabled,
                  ),
                  const SizedBox(height: 8),
                  _buildDiagnosticRow(
                    label: 'Permissão GPS',
                    status: report.gpsPermission.name,
                    isOk: report.gpsPermission == LocationPermissionStatus.whileInUse ||
                        report.gpsPermission == LocationPermissionStatus.always,
                  ),
                  const SizedBox(height: 8),
                  _buildDiagnosticRow(
                    label: 'Base SQLite R*Tree',
                    status: report.isDatabaseHealthy
                        ? '${report.totalPoisIndexed} POIs indexados'
                        : 'Erro de integridade',
                    isOk: report.isDatabaseHealthy && report.totalPoisIndexed > 0,
                  ),
                  const SizedBox(height: 8),
                  _buildDiagnosticRow(
                    label: 'Conectividade',
                    status: report.isWifiConnected
                        ? 'Wi-Fi'
                        : report.isNetworkConnected
                            ? 'Dados Móveis'
                            : 'Offline (OK)',
                    isOk: true,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDiagnosticRow({
    required String label,
    required String status,
    required bool isOk,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB0B0B0),
            fontSize: 14,
          ),
        ),
        Row(
          children: [
            Icon(
              isOk ? Icons.check_circle : Icons.error_outline,
              size: 16,
              color: isOk ? SentinelaTheme.alertNormal : SentinelaTheme.alertCritical,
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                color: isOk ? Colors.white : SentinelaTheme.alertCritical,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
