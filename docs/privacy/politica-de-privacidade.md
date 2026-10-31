# Política de Privacidade — Sentinela Radar

> **Última atualização:** 31 de Outubro de 2026  
> **Versão:** 1.0.0  
> **Identificador do Pacote:** `br.com.sentinela.sentinela`

O **Sentinela** foi concebido sob o princípio inegociável de **Privacidade Absoluta e Arquitetura 100% Offline-First**. Esta política de privacidade detalha de forma transparente como o aplicativo lida com seus dados durante a condução veicular.

---

## 1. Princípio Fundamental: Zero Coleta & Zero Telemetria

1. **Processamento Estritamente Local:** O sinal do sensor de GPS (coordenadas de latitude, longitude, rumo e velocidade instantânea) é processado **exclusivamente na memória volátil (RAM)** do seu próprio dispositivo móvel para calcular a distância e orientar a aproximação dos radares de trânsito, lombadas, semáforos e praças de pedágio.
2. **Nenhuma Transmissão para a Nuvem:** Nenhuma coordenada geográfica, velocidade aferida, trajeto percorrido, histórico de viagens ou metadados de identificação do aparelho é transmitido para servidores remotos, nuvem ou terceiros.
3. **Ausência Total de Rastreamento (Zero Tracking):**
   * Não utilizamos identificadores de publicidade (IDFA no iOS ou GAID no Android).
   * Não incluímos SDKs de terceiros para rastreamento de comportamento, telemetria de anúncios ou análise de engajamento comercial.
   * Não comercializamos, compartilhamos ou monetizamos dados de condutores em nenhuma hipótese.

---

## 2. Permissões de Sistema Requeridas

| Permissão | Finalidade Operacional | Política de Retenção |
| :--- | :--- | :--- |
| **Localização em Primeiro Plano (`ACCESS_FINE_LOCATION`)** | Calcular a velocidade real e detectar radares à frente no velocímetro do painel. | Efêmero (descartado da RAM imediatamente após o cálculo). |
| **Localização em Segundo Plano (`ACCESS_BACKGROUND_LOCATION`)** | Permitir a continuidade dos alertas quando o aplicativo operar em janela flutuante (Overlay) ou sob outros navegadores (Waze, Google Maps). | Efêmero (sem retenção em disco). |
| **Serviço de Primeiro Plano (`FOREGROUND_SERVICE_LOCATION`)** | Manter o processo ativo contra o encerramento agressivo por gerenciadores de bateria do Android durante viagens. | Apenas em tempo de execução. |
| **Acesso a Redes Wi-Fi (`ACCESS_NETWORK_STATE`)** | Verificar conexão Wi-Fi ativa para permitir a sincronização in-app e download sob demanda de bases abertas governamentais. | Apenas leitura de status. |
| **Sobreposição de Tela (`SYSTEM_ALERT_WINDOW`)** | Renderizar a miniatura flutuante do velocímetro e sonar sobre navegadores de mapas. | Local na tela. |

---

## 3. Armazenamento Local e Soberania do Usuário

* **Base de Dados Embarcada:** O banco local de POIs (`sentinela_brasil.db`) opera em SQLite com extensão espacial R\*Tree, armazenado localmente no dispositivo.
* **Histórico de Passagens e Pontos Customizados:** Qualquer registro de passagem ou radar móvel marcado pelo condutor é armazenado **estritamente no banco de dados local do smartphone**.
* **Controle Total pelo Usuário:**
  * O condutor pode exportar seus dados a qualquer momento em formatos abertos (JSON, GPX 1.1 e KML 2.2).
  * A limpeza dos dados do aplicativo ou a sua desinstalação remove permanentemente todos os registros locais do aparelho.

---

## 4. Conformidade Internacional de Lojas

* **Apple App Store:** Em conformidade estrita com o **Apple Privacy Manifest** (`PrivacyInfo.xcprivacy`), declarando `NSPrivacyTracking = false` e zero coleta de dados.
* **Google Play Store:** Em conformidade com a seção **Google Play Data Safety**, declarando que nenhuma informação é coletada, compartilhada ou transmitida externamente.
* **Legislação Aplicável:** Alinhado aos padrões da **LGPD (Lei Geral de Proteção de Dados - Lei nº 13.709/2018)** no Brasil e do **GDPR (General Data Protection Regulation)** na União Europeia.
