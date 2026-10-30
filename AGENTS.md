# AGENTS.md — Base de Conhecimento e Diretrizes Centrais: Sentinela

> **Aviso Obrigatório para Agentes de IA:**
> Todo prompt de entrada DEVE obrigatoriamente ler e analisar este arquivo antes de executar qualquer tarefa, verificando se há contradições com as regras, restrições e definições arquiteturais aqui documentadas.
> Em caso de conflito, as regras deste arquivo prevalecem.
> **Ciclo Completo Obrigatório por Iteração:** NENHUMA iteração é considerada concluída sem cumprir o fluxo integral: branch isolada ➔ testes BDD/TDD (cobertura ≥90%) ➔ push ➔ PR e merge em `develop` ➔ PR final de `develop` para `main` com relatório completo e link fornecido ao usuário.

---

## 1. Identidade e Visão do Produto
* **Nome do Produto:** Sentinela
* **Repositório Remoto:** `git@github.com:thcborges/sentinela-radar.git`
* **Público e Plataformas-Alvo:** Dispositivos móveis Android e iOS.
* **Design System Mandatório:** **Material Design 3 (M3) do Google** (`https://m3.material.io/`), com tema escuro analítico (*Dark HUD/Dashboard*), cores tonais dinâmicas, tipografia legível e superfícies semânticas.
* **Missão do Produto:** Aplicativo móvel para alerta antecipado de radares de velocidade (fixos e móveis), radares de semáforo (avanço de sinal vermelho e parada sobre faixa), lombadas físicas/eletrônicas e praças de pedágio (convencionais e pórticos Free Flow) em todo o Brasil.
* **Pilares Fundamentais:**
  1. **100% Offline-First:** Toda a base de POIs (~70.000 pontos com índice espacial SQLite R*Tree, ~15–18 MB) opera localmente sem necessidade de conexão 4G/5G ou dados móveis.
  2. **Atualização In-App Sob Demanda:** O próprio aplicativo executa rotinas de download e sincronização direta com dados abertos (OpenStreetMap / Overpass API, DNIT, INMETRO, ANTT) via Wi-Fi, com staging tables e swap atômico no SQLite.
  3. **Privacidade Absoluta:** O sinal e cálculo de GPS são processados estritamente na memória volátil do dispositivo. Nenhuma coordenada, histórico de trajeto ou telemetria é transmitida para a nuvem.
  4. **Modo Overlay (Janela Flutuante):** Operação contínua em segundo plano com overlay minimizado (velocímetro, distância regressiva e alerta visual) sobreposto a navegadores como Waze, Google Maps ou Uber.
  5. **Sem Restrições:** Sem limites de quilometragem, sem login obrigatório e sem modelo de assinaturas pagas.

---

## 2. Meta-Regras Inquebráveis de Desenvolvimento

### 2.1. Versionamento Git, Ciclo de Branches & Pull Requests

> [!IMPORTANT]
> **OBRIGATORIEDADE DE CICLO COMPLETO PARA TODA E QUALQUER ITERAÇÃO:**
> O fluxo estruturado de branches DEVE ser executado integralmente em **CADA iteração** de desenvolvimento, sem exceções. Não é permitido finalizar uma tarefa sem completar o ciclo até a abertura do Pull Request para `main` com o link disponibilizado ao usuário.

1. **Branch Isolada por Iteração:**
   * Toda e qualquer implementação DEVE ser realizada em branch separada (`feat/<nome>` ou `fix/<nome>`).
   * Salvo se o usuário iniciar expressamente uma nova worktree, uma nova branch **a partir da branch `main`** DEVE ser criada para cada interação.
2. **Validação Remota com Trivy & Merge em Develop:**
   * Ao finalizar o desenvolvimento e os testes locais, realiza-se o push da branch para o repositório remoto (`git push origin <branch>`).
   * Abre-se o Pull Request apontando para a branch `develop`, disparando a esteira de CI do GitHub Actions com validação de segurança pelo **Trivy** e a suíte completa de testes.
   * Após a validação com sucesso dos checks de CI e Trivy, a branch DEVE ser mesclada (*merge*) com a branch `develop` para publicação no ambiente de desenvolvimento.
3. **Agente Revisor de Pull Request (`pr-ui-reviewer`) & Testes de Estresse de UI:**
   * Um agente dedicado (`pr-ui-reviewer`) executa a auditoria de usabilidade, aderência ao Material Design 3 e estresse da UI.
   * O agente valida os testes de widget e testes de integração herméticos em Flutter (`flutter test`), simulando trajetos de GPS (GPX/Mocks), renderização de componentes HUD/Velocímetro e estabilidade da base SQLite local em memória/arquivo de teste.
4. **Conclusão Obrigatória da Iteração, PR para `main` e Notificação Telegram:**
   * Imediatamente após o merge em `develop` e a validação dos testes, o agente DEVE obrigatoriamente criar o Pull Request apontando da branch `develop` para a branch de produção `main`.
   * A descrição do Pull Request DEVE conter um relatório completo e detalhado de tudo o que foi implementado na iteração.
   * O agente DEVE informar o link direto do Pull Request gerado para `main` na sua resposta ao usuário.
   * Dispara-se simultaneamente uma notificação estruturada via **Telegram Bot** informando o encerramento da iteração, contendo a mesma descrição detalhada e o link direto do Pull Request aprovado e pronto para o merge.
5. **Documentação Obrigatória no GitHub Pages:**
   * A documentação oficial do projeto é mantida em **VitePress** dentro do diretório `docs/`, com tema dark alinhado ao Material Design 3 e suporte a Markdown e fórmulas LaTeX.
   * É publicada continuamente no **GitHub Pages** no endereço: `https://thcborges.github.io/sentinela-radar/`.
   * A documentação deve permitir um entendimento superficial na visão geral (Nível 1) e aprofundamento técnico modular nos detalhes de domínio (Nível 2).
6. **Commits Semânticos Obrigatórios:**
   * Todo resultado de prompt DEVE ser commitado com uma mensagem clara, semântica e objetiva (ex: `feat(...)`, `fix(...)`, `test(...)`, `docs(...)`, `refactor(...)`).

---

### 2.2. Metodologia BDD (Behavior Driven Development) & TDD (Test Driven Development)

1. **Nenhum código de produção deve ser escrito sem um teste prévio que falhe.**
2. **Cobertura Mínima de Testes:** **≥ 90%** em todos os pacotes e módulos de código.
3. **Tratamento de Bugs e Erros:** Qualquer correção de erro DEVE incluir um **teste de regressão** reproduzindo o bug antes da correção, garantindo que o erro nunca volte a ocorrer.
4. **Ordem Estrita de Execução de Testes:**
   * **Passo 1:** Ao desenvolver uma nova feature, execute *apenas* os testes da respectiva feature.
   * **Passo 2:** Somente após os testes da feature passarem com 100% de sucesso, execute a **suíte completa de testes** do projeto para atestar a não-regressão.

---

## 3. Arquitetura do Sistema e Stack Tecnológica

O projeto é estruturado em **Flutter (Dart)** com foco em separação estrita de camadas e desacoplamento para viabilizar cobertura de testes ≥ 90%:

```
sentinela/
├── lib/
│   ├── core/                  # Módulos puros: fórmulas geo (Haversine/Bearing), State Machine
│   ├── data/                  # SQLite com R*Tree, parsing OSM/CKAN, sincronizador com Staging
│   ├── features/
│   │   ├── dashboard/         # HUD M3, velocímetro de alto contraste, bússola e sonar
│   │   ├── overlay/           # Janela flutuante Picture-in-Picture / System Alert Window
│   │   └── settings/          # Tela de atualização da base, filtros e preferências de áudio
│   ├── background/            # Foreground Service e isolamento de ciclo de vida
│   └── main.dart              # Ponto de entrada do aplicativo
├── test/
│   ├── core/                  # Testes unitários do motor matemático e geo-cálculos
│   ├── data/                  # Testes do banco SQLite, swap atômico e deduplicação
│   └── features/              # Testes de Widget dos componentes Material Design 3
├── integration_test/          # Testes de integração simulando trajetos de GPS (GPX)
├── docs/                      # Documentação VitePress publicada no GitHub Pages
└── .github/
    └── workflows/             # CI/CD: flutter analyze, flutter test (≥90%), Trivy, docs deploy
```

### 3.1. Stack Tecnológica
* **Linguagem & Framework:** Dart & Flutter (SDK mais recente com Material 3 nativo ativado por padrão `useMaterial3: true`).
* **Gerenciamento de Estado:** **BLoC / Cubit (`flutter_bloc`)** para todas as máquinas de estado reativas (AlertMachine, GPS Stream, Sync Engine e Settings). Testes rigorosos com o pacote oficial `bloc_test`, garantindo separação absoluta entre regras de negócio e renderização de tela.
* **Persistência Offline:** `sqflite` / `sqlite3` com extensão espacial compilada **R\*Tree**.
* **Processamento Concorrente:** `compute()` e `Isolates` dedicados para ingestão de dados e parsing pesado sem travar o event loop da UI (60/120 fps constantes).
* **Áudio e TTS:** Motores de Text-to-Speech nativos do SO (Google TTS no Android e AVSpeechSynthesizer no iOS) com pacotes offline em `pt-BR`.
* **Janela Flutuante & Segundo Plano Multiplataforma:**
  * **Android:** Overlay flutuante e arrastável via canal nativo (`SYSTEM_ALERT_WINDOW` / `flutter_overlay_window`) operando sobre Waze/Maps com velocímetro, sonar e alerta pulsante.
  * **iOS:** Integração com **Live Activities & Dynamic Island** (iOS 16.1+) para exibição de velocidade e alertas no topo/tela de bloqueio, complementado por canal de áudio com atenuação (*Audio Ducking*) e síntese de voz nativa via `AVSpeechSynthesizer`.
* **Serviço de Background:** Foreground Service no Android com notificação persistente para blindagem contra Doze Mode e gerenciadores agressivos de bateria.

---

## 4. Diretrizes de Interface e Experiência do Usuário (Material Design 3)

* **Diretrizes Visuais:** Google Material Design 3 (M3).
* **Tema Principal:** Dark HUD (fundo escuro de alto contraste `#121212` / `#1E1E1E` para não ofuscar a visão do motorista à noite ou sob luz solar intensa).
* **Paleta Semântica de Alertas:**
  * Verde/Normal: Velocidade dentro do limite da via.
  * Amarelo/Atenção: Aproximação de radar, lombada ou semáforo com velocidade compatível.
  * Vermelho/Crítico: Excesso de velocidade em aproximação a ponto de fiscalização (efeito pulsante).
  * Azul/Informativo: Praças de pedágio e postos policiais.
* **Componentes Principais:**
  * Velocímetro Digital M3 de alta legibilidade com tipografia monoespaçada/tabular para evitar saltos visuais.
  * Sonar Circular frontal com representação angular dos pontos à frente.
  * Card flutuante (Overlay M3) com elevações tonais e cantos arredondados (Shape Token: Rounded Large).
  * Painel de configurações com M3 Switch, Sliders e Progress Indicators lineares.

---

## 5. Núcleo Matemático e Motor de Alertas

1. **Cálculo de Distância Dinâmica de Antecipação:**
   $$D_{alerta} = \max\left(D_{min},\, v \cdot t_{antecipacao}\right)$$
   * Radares de Velocidade: $t_{antecipacao} \approx 12 \text{ a } 15 \text{ s}$.
   * Radares Semafóricos: $D_{alerta} \approx 180 \text{ a } 250 \text{ m}$.
   * Lombadas Físicas: $D_{alerta} \approx 80 \text{ a } 120 \text{ m}$.
   * Pedágios: $D_{alerta} \approx 800 \text{ a } 1.000 \text{ m}$.
2. **Filtragem Angular e Rumo (Bearing):**
   * Descarte instantâneo de vias perpendiculares ou sentidos contrários em pistas duplas ($\le 35^\circ$ de tolerância direcional).
3. **Máquina de Estados de Alerta:**
   $$\text{IDLE} \longrightarrow \text{APPROACHING} \longrightarrow \text{ALERTING} \longrightarrow \text{OVER\_SPEED} \longrightarrow \text{PASSED}$$

---

## 6. Estratégia de Persistência e Sincronização Local

* **Banco Local:** SQLite compilado com extensão espacial nativa **R\*Tree**.
* **Base Pré-embarcada nos Assets:** O instalador já inclui `assets/db/sentinela_brasil.db` (~15–18 MB compilado), garantindo funcionamento 100% offline imediato no primeiro uso sem requisições de rede.
* **Pipeline de Geração de Seed:** Script automatizado (`tools/generate_seed_db.dart`) responsável por baixar, higienizar e compilar a base nacional a partir dos dados abertos governamentais e do OpenStreetMap.
* **Indexação Espacial:** Bounding Box sobre latitude/longitude para queries espaciais na ordem de microssegundos.
* **Atualização Segura (Atomic Staging Swap):**
  * Criação de tabelas `pois_staging` e `pois_index_staging`.
  * Inserção em lote (*batch*).
  * Swap atômico de tabelas sem travamento da base ativa.
  * Rollback automático em caso de perda de conexão Wi-Fi.
