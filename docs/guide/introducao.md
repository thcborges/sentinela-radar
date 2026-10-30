# Visão Geral do Produto — Sentinela

O **Sentinela** é um aplicativo móvel desenvolvido em **Flutter** voltado para motoristas e motociclistas em todo o território brasileiro, oferecendo alertas antecipados e precisos sobre pontos de fiscalização e moderação viária sem dependência de internet.

---

## 🎯 Missão e Escopo
O aplicativo foi projetado para operar com **zero latência de rede** e **privacidade irrestrita**, monitorando continuamente:
- **Radares de Velocidade:** Fixos, portáteis e áreas com histórico de radares móveis.
- **Radares de Semáforo:** Fiscalização conjunta de velocidade, avanço de sinal vermelho e parada sobre faixa de pedestres.
- **Câmeras de Cruzamento:** Fiscalização exclusiva de sinal vermelho e conversões proibidas.
- **Lombadas e Quebra-molas:** Redutores físicos e lombadas eletrônicas com painel digital de velocidade.
- **Praças de Pedágio & Free Flow:** Pedágios convencionais com cabine e pórticos automáticos sem cancela.
- **Postos Policiais:** Bases fixas da Polícia Rodoviária Federal (PRF) e Polícias Rodoviárias Estaduais.

---

## 🏛️ Os Pilares Centrais

### 1. 100% Offline-First
O instalador do Sentinela já traz embutido o arquivo de banco de dados compilado `assets/db/sentinela_brasil.db` (~15–18 MB), contendo dezenas de milhares de pontos georreferenciados em uma estrutura espacial de altíssimo desempenho (**SQLite R\*Tree**). O motorista pode viajar por estradas sem qualquer sinal de celular (3G/4G/5G) e manter todos os avisos sonoros e visuais ativos.

### 2. Atualização In-App Sob Demanda
Quando conectado a uma rede Wi-Fi, o condutor pode acionar o módulo de sincronização in-app (`PoiSyncService`). O aplicativo baixa os deltas de dados abertos diretamente de fontes públicas e executa o processamento pesado em um `Isolate` de background, garantindo 60/120 fps fluidos na interface gráfica.

### 3. Privacidade Absoluta e Condução Segura
* **Sem Conta ou Login:** O aplicativo não solicita e-mail, telefone, cadastro ou autenticação OAuth.
* **Sem Telemetria na Nuvem:** Coordenadas de GPS, velocidades e trajetos são descartados instantaneamente após o cálculo matemático na memória volátil (RAM).
* **Histórico 100% Local:** Métricas de conformidade e passagens por radares ficam armazenadas unicamente no banco SQLite do aparelho e podem ser apagadas com um único clique.

### 4. Modo Overlay (Janela Flutuante)
No Android, o Sentinela utiliza o canal de sobreposição (`SYSTEM_ALERT_WINDOW`) para projetar um mini velocímetro e cartão de alerta diretamente sobre navegadores GPS externos (como Waze, Google Maps ou Uber). No iOS, a integração utiliza Live Activities e Dynamic Island.
