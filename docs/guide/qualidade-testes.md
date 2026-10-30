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
| `core/engine/` (`AlertMachine`) | 91 / 94 | **96.8%** | ✅ Aprovado |
| `core/audio/` (`AudioAlertPlayer`, TTS) | 40 / 41 | **97.5%** | ✅ Aprovado |
| `data/database/` & `repository/` | 130 / 132 | **98.4%** | ✅ Aprovado |
| `data/sync/` (`PoiSyncService`, Parser) | 121 / 128 | **94.5%** | ✅ Aprovado |
| `features/dashboard/` (Speedometer, Sonar, Banner) | 209 / 239 | **92.4%** | ✅ Aprovado |
| `features/overlay/` (`FloatingOverlayWidget`, Service) | 79 / 80 | **98.7%** | ✅ Aprovado |
| `features/stats/` (`PassageRepository`, `StatsCubit`) | 148 / 150 | **98.6%** | ✅ Aprovado |
| `background/` (`BackgroundTrackingService`) | 43 / 43 | **100.0%** | ✅ Aprovado |
| **Total do Projeto** | **> 1100 linhas** | **> 94%** | ✅ Aprovado |

---

## 🔒 Auditoria de Segurança com Trivy

Todas as branches e Pull Requests submetidos ao repositório disparam o analisador de vulnerabilidades de segurança e segredos **Trivy** no GitHub Actions, garantindo que dependências desatualizadas ou vulnerabilidades de segurança sejam barradas antes do merge em `develop` e `main`.
