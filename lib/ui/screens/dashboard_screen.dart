import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentinela/core/backup/backup_restore_service.dart';
import 'package:sentinela/core/diagnostics/system_diagnostics.dart';
import 'package:sentinela/core/engine/section_control_machine.dart';
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
  final BackupRestoreService? backupService;

  const DashboardScreen({
    super.key,
    required this.syncService,
    this.statsCubit,
    this.wakelockManager,
    this.locationService,
    this.overlayService,
    this.diagnosticsService,
    this.backupService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<VehiclePosition>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    try {
      widget.wakelockManager?.enable();
    } catch (_) {}

    _initLocationTracking();
  }

  void _initLocationTracking() async {
    if (widget.locationService == null) return;

    try {
      final perm = await widget.locationService!.checkPermission();
      if (perm == LocationPermissionStatus.denied) {
        await widget.locationService!.requestPermission();
      }
    } catch (_) {}

    if (!mounted) return;

    try {
      _locationSubscription = widget.locationService!
          .getPositionStream()
          .listen(
            (pos) {
              if (mounted) {
                context.read<DashboardCubit>().onLocationUpdated(pos);
              }
            },
            onError: (_) {
              // Previne interrupção e tela branca caso ocorra falha de hardware ou permissão
            },
          );
    } catch (_) {}
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    try {
      widget.wakelockManager?.disable();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        final int? speedLimit = state.activeAlert?.poi.speedLimit;

        return Scaffold(
          backgroundColor: state.isHudMirrorMode ? Colors.black : null,
          appBar: AppBar(
            backgroundColor: state.isHudMirrorMode ? Colors.black : null,
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
                key: const Key('dashboard_hud_mirror_button'),
                icon: Icon(
                  state.isHudMirrorMode
                      ? Icons.flip_to_back_rounded
                      : Icons.screen_rotation_rounded,
                  color: state.isHudMirrorMode ? SentinelaTheme.alertNormal : null,
                ),
                tooltip: state.isHudMirrorMode
                    ? 'Desativar Modo HUD'
                    : 'Ativar Modo HUD Para-brisa',
                onPressed: () => context.read<DashboardCubit>().toggleHudMirrorMode(),
              ),
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
                        backupService: widget.backupService,
                        initialPreferences: cubit.alertMachine.preferences,
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
          body: Container(
            color: state.isHudMirrorMode ? Colors.black : null,
            child: Transform(
              alignment: Alignment.center,
              transform: state.isHudMirrorMode
                  ? Matrix4.rotationY(math.pi)
                  : Matrix4.identity(),
              child: SafeArea(
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
                                      isHighContrast: state.highContrastMode,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildBadges(state),
                                  if (state.sectionControlState.isActive)
                                    _buildSectionControlBanner(state.sectionControlState),
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

                          _buildBadges(state),

                          const SizedBox(height: 12),

                          // Banner de Radar de Trecho / Velocidade Média Ativo
                          if (state.sectionControlState.isActive)
                            _buildSectionControlBanner(state.sectionControlState),

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
                              isHighContrast: state.highContrastMode,
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
              ),
            ),
          ),
          floatingActionButton: state.isHudMirrorMode
              ? null
              : FloatingActionButton.extended(
                  key: const Key('dashboard_quick_report_fab'),
                  onPressed: () => _showQuickReportModal(context),
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('Marcar Ponto'),
                  backgroundColor: SentinelaTheme.primaryGold,
                  foregroundColor: Colors.black,
                ),
        );
      },
    );
  }

  Widget _buildSectionControlBanner(SectionControlState sectionState) {
    return Container(
      key: const Key('dashboard_section_control_banner'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: sectionState.isOverSpeed
            ? SentinelaTheme.alertCritical.withValues(alpha: 0.15)
            : SentinelaTheme.alertWarning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sectionState.isOverSpeed
              ? SentinelaTheme.alertCritical
              : SentinelaTheme.alertWarning,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.speed_rounded,
                  size: 20,
                  color: sectionState.isOverSpeed
                      ? SentinelaTheme.alertCritical
                      : SentinelaTheme.alertWarning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'RADAR DE TRECHO (VEL. MÉDIA)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: sectionState.isOverSpeed
                              ? SentinelaTheme.alertCritical
                              : SentinelaTheme.alertWarning,
                        ),
                      ),
                      Text(
                        '${sectionState.averageSpeedKmh.toStringAsFixed(1)} km/h / Limite: ${sectionState.corridor?.speedLimitKmh.toStringAsFixed(0)} km/h',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${sectionState.remainingDistanceMeters.toStringAsFixed(0)}m rest.',
                style: const TextStyle(fontSize: 11, color: Color(0xFFB0B0B0)),
              ),
              if (sectionState.targetRemainingSeconds > 0)
                Text(
                  'Aguarde ${sectionState.targetRemainingSeconds.toStringAsFixed(0)}s',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: SentinelaTheme.alertWarning,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadges(DashboardState state) {
    if (!state.isTunnelMode && (state.activeCluster == null || !state.activeCluster!.isMultiPoint)) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.isTunnelMode)
          Container(
            key: const Key('dashboard_tunnel_badge'),
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: SentinelaTheme.alertWarning.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SentinelaTheme.alertWarning, width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 14, color: SentinelaTheme.alertWarning),
                SizedBox(width: 6),
                Text(
                  'TÚNEL / NAVEGAÇÃO INERCIAL',
                  style: TextStyle(
                    color: SentinelaTheme.alertWarning,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        if (state.activeCluster != null && state.activeCluster!.isMultiPoint)
          Container(
            key: const Key('dashboard_cluster_badge'),
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: SentinelaTheme.primaryGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SentinelaTheme.primaryGold, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.layers_rounded, size: 13, color: SentinelaTheme.primaryGold),
                const SizedBox(width: 6),
                Text(
                  '+${state.activeCluster!.associatedPois.length} fiscalização colocalizada',
                  style: const TextStyle(
                    color: SentinelaTheme.primaryGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
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

  void _showQuickReportModal(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Marcar Ponto na Via',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cadastre um ponto offline na sua localização GPS atual',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildReportChip(
                      sheetContext,
                      cubit,
                      label: 'Radar Móvel',
                      icon: Icons.camera_alt_rounded,
                      type: PoiType.mobileRadar,
                      keyName: 'quick_report_mobile_radar',
                    ),
                    _buildReportChip(
                      sheetContext,
                      cubit,
                      label: 'Radar Fixo',
                      icon: Icons.speed_rounded,
                      type: PoiType.fixedRadar,
                      keyName: 'quick_report_fixed_radar',
                    ),
                    _buildReportChip(
                      sheetContext,
                      cubit,
                      label: 'Polícia',
                      icon: Icons.local_police_rounded,
                      type: PoiType.highwayPatrol,
                      keyName: 'quick_report_highway_patrol',
                    ),
                    _buildReportChip(
                      sheetContext,
                      cubit,
                      label: 'Lombada',
                      icon: Icons.waves_rounded,
                      type: PoiType.physicalSpeedBump,
                      keyName: 'quick_report_speed_bump',
                    ),
                    _buildReportChip(
                      sheetContext,
                      cubit,
                      label: 'Semáforo',
                      icon: Icons.traffic_rounded,
                      type: PoiType.trafficLightRadar,
                      keyName: 'quick_report_traffic_light',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportChip(
    BuildContext sheetContext,
    DashboardCubit cubit, {
    required String label,
    required IconData icon,
    required PoiType type,
    required String keyName,
  }) {
    return ActionChip(
      key: Key(keyName),
      avatar: Icon(icon, size: 18, color: SentinelaTheme.primaryGold),
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFF2C2C2C),
      side: const BorderSide(color: Colors.white12),
      onPressed: () async {
        Navigator.pop(sheetContext);
        final reported = await cubit.reportQuickPoi(type: type);
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              key: const Key('quick_report_success_snackbar'),
              content: Text(
                reported != null
                    ? '$label marcado com sucesso!'
                    : 'GPS sem sinal no momento da marcação.',
              ),
              backgroundColor: reported != null ? SentinelaTheme.alertNormal : SentinelaTheme.alertWarning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }
}
