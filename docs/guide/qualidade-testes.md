# Metodologia BDD/TDD & Garantia de Qualidade

A estabilidade e precisão do **Sentinela** são garantidas por uma política inegociável de desenvolvimento guiado por testes (**BDD/TDD**), auditoria de cobertura $\ge 90\%$ e varreduras automatizadas de segurança.

---

## 🎯 Meta-Regras Inquebráveis

1. **Nenhum código de produção é escrito sem teste prévio que falhe.**
2. **Cobertura Mínima de Testes:** **$\ge 90\%$** em todos os módulos e pacotes de código.
3. **Testes de Regressão Obrigatórios:** Qualquer correção de bug exige um teste prévio reproduzindo o defeito.
4. **Ordem Estrita de Execução:**
   - **Passo 1:** Execução dos testes unitários da respectiva funcionalidade.
   - **Passo 2:** Execução da suíte completa do projeto após 100% de sucesso.

---

## 📊 Cobertura Atual por Módulo

| Módulo / Pacote | Linhas Cobertas | Cobertura (%) | Status |
| :--- | :---: | :---: | :---: |
| `core/geo/` (Haversine, Bearing, Bounding Box) | 61 / 63 | **96.8%** | ✅ Aprovado |
| `core/engine/` (`AlertMachine`, `SectionControlMachine`, `AdaptiveGpsSampler`, Preferences) | 242 / 255 | **94.9%** | ✅ Aprovado |
| `core/security/` (`DatabaseIntegrityValidator` SHA-256 e PRAGMA) | 29 / 31 | **93.5%** | ✅ Aprovado |
| `core/export/` (`RouteExporter` GPX 1.1 e KML 2.2 Offline) | 97 / 97 | **100.0%** | ✅ Aprovado |
| `core/platform/` (`LiveActivityService`, Dynamic Island Adapter) | 62 / 66 | **93.9%** | ✅ Aprovado |
| `core/backup/` (`BackupRestoreService` 100% Offline) | 48 / 48 | **100.0%** | ✅ Aprovado |
| `core/diagnostics/` (`SystemDiagnosticsService`) | 32 / 32 | **100.0%** | ✅ Aprovado |
| `core/audio/` (`AudioAlertPlayer`, `PlatformTtsEngine`, `ToneGenerator`, Formatter) | 83 / 84 | **98.8%** | ✅ Aprovado |
| `core/toll/` (`TollRateEstimator` e tarifas Free Flow) | 21 / 21 | **100.0%** | ✅ Aprovado |
| `core/location/` (`GeolocatorLocationService`) | 26 / 27 | **96.3%** | ✅ Aprovado |
| `core/hardware/` (`PlatformWakelockManager`) | 9 / 9 | **100.0%** | ✅ Aprovado |
| `core/network/` (`PlatformConnectivityChecker`) | 13 / 13 | **100.0%** | ✅ Aprovado |
| `core/theme/` & `models/` (Theme, POI Models, `UserReportedPoi`) | 119 / 120 | **99.2%** | ✅ Aprovado |
| `data/database/` & `repository/` (`DatabaseManager`, `PoiRepository`, `CustomPoiRepository`) | 209 / 211 | **99.1%** | ✅ Aprovado |
| `data/sync/` (`PoiSyncService`, `FederalOpenDataParser`, `SyncMirrorManager`, Parser OSM) | 309 / 324 | **95.4%** | ✅ Aprovado |
| `features/dashboard/` (Speedometer, Sonar, Banner, Section, Quick Report FAB) | 506 / 516 | **98.1%** | ✅ Aprovado |
| `features/overlay/` (`FloatingOverlayWidget`, `OverlayService`, Quick Report Overlay) | 82 / 83 | **98.8%** | ✅ Aprovado |
| `features/settings/` (`SettingsScreen`) | 176 / 184 | **95.7%** | ✅ Aprovado |
| `features/stats/` (`PassageRepository`, `StatsCubit`, `StatsScreen`, Export GPX/KML) | 262 / 266 | **98.5%** | ✅ Aprovado |
| `background/` (`BackgroundTrackingService`) | 74 / 77 | **96.1%** | ✅ Aprovado |
| `main.dart` & `overlayMain` | 70 / 74 | **94.6%** | ✅ Aprovado |
| **Total Consolidado** | **2530 / 2601 linhas** | **97.27%** | ✅ Aprovado (278 testes) |

---

## 🔒 Auditoria de Segurança com Trivy

Todas as branches e Pull Requests submetidos ao repositório disparam o analisador de vulnerabilidades de segurança e segredos **Trivy** no GitHub Actions, garantindo que dependências desatualizadas ou vulnerabilidades de segurança sejam barradas antes do merge em `develop` e `main`.
