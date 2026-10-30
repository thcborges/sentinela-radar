# Sentinela — Alerta Inteligente de Radares Offline

<div align="center">
  <p><strong>Aplicativo Móvel Offline-First em Flutter para Alerta Antecipado de Radares, Semáforos, Lombadas e Pedágios no Brasil</strong></p>
  <p>Design System <strong>Google Material Design 3 (M3)</strong> com tema analítico <strong>Dark HUD</strong> de alto contraste.</p>
</div>

---

## 🚀 Pilares do Sentinela

1. **100% Offline-First:** Toda a base de POIs (~70.000 pontos com índice espacial SQLite R*Tree, ~15–18 MB) opera localmente sem necessidade de conexão 4G/5G ou dados móveis.
2. **Atualização In-App Sob Demanda:** O próprio aplicativo executa rotinas de download e sincronização direta com dados abertos (OpenStreetMap / Overpass API, DNIT, INMETRO, ANTT) via Wi-Fi, com tabelas de *staging* e troca atômica (*swap*) no SQLite.
3. **Privacidade Absoluta:** O sinal e cálculo de GPS são processados estritamente na memória volátil do dispositivo. Nenhuma coordenada, histórico de trajeto ou telemetria é transmitida para servidores externos.
4. **Modo Overlay (Janela Flutuante):** Operação contínua em segundo plano com miniatura flutuante M3 arrastável (velocímetro, distância regressiva e alerta visual) sobreposta a navegadores como Waze, Google Maps ou Uber.
5. **Áudio & Síntese Vocal Offline (TTS):** Mensagens faladas especializadas em português brasileiro (`pt-BR`) via engines nativas do SO e bipes de proximidade com cadência progressiva inversamente proporcional à distância (efeito sonar).
6. **Sem Restrições:** Sem limites de quilometragem, sem login obrigatório e sem assinaturas pagas.

---

## 📐 Arquitetura do Sistema

```
sentinela/
├── lib/
│   ├── core/
│   │   ├── audio/             # Gerenciador de áudio, formatação TTS e bipes de proximidade
│   │   ├── engine/            # AlertMachine (Máquina de estados reativa de alerta)
│   │   ├── geo/               # Fórmulas geodésicas de Haversine, Bearing e Bounding Box
│   │   ├── models/            # POI, Radar, TrafficLight, TollBooth, SpeedBump, VehiclePosition
│   │   └── theme/             # Material Design 3 Dark HUD de alto contraste
│   ├── data/
│   │   ├── database/          # SQLite R*Tree, queries espaciais pré-compiladas
│   │   ├── repository/        # PoiRepository com busca por Bounding Box e raio
│   │   └── sync/              # Sincronizador In-App com staging tables e swap atômico
│   ├── features/
│   │   ├── dashboard/         # HUD M3, velocímetro digital, sonar frontal e banner de alerta
│   │   ├── overlay/           # Miniatura flutuante Picture-in-Picture / System Alert Window
│   │   └── settings/          # Tela de atualização da base, filtros e preferências de áudio/overlay
│   ├── background/
│   │   └── tracking_service/  # Foreground Service persistente para rastreamento em 2º plano
│   └── main.dart              # Ponto de entrada do aplicativo Sentinela
└── test/                      # Testes herméticos BDD/TDD (112 testes, 94.83% de cobertura)
```

---

## 🧪 Qualidade de Código & Metodologia BDD/TDD

* **Metodologia:** BDD (Behavior Driven Development) & TDD (Test Driven Development) estrito.
* **Cobertura de Testes:** **94.83%** (112 testes passando).
* **Análise Estática:** `flutter analyze --fatal-infos` com **0 avisos, 0 erros e 0 notas**.
* **Varredura de Segurança:** Trivy no pipeline de CI do GitHub Actions.

---

## 🛠️ Como Executar os Testes

```bash
# Executar todos os testes com relatório de cobertura
flutter test --coverage

# Executar análise estática rigorosa
flutter analyze --fatal-infos
```
