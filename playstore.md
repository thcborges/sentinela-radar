# Guia de Publicação do Sentinela na Google Play Store

Este documento detalha o passo a passo completo e normatizado para o empacotamento, assinatura e publicação oficial do aplicativo **Sentinela Radar** no Google Play Console.

---

## 📋 Sumário
1. [Pré-requisitos e Conta de Desenvolvedor](#1-pré-requisitos-e-conta-de-desenvolvedor)
2. [Geração da Chave Criptográfica de Produção (Upload Keystore)](#2-geração-da-chave-criptográfica-de-produção-upload-keystore)
3. [Configuração do `key.properties` e Build do App Bundle](#3-configuração-do-keyproperties-e-build-do-app-bundle)
4. [Criação do Aplicativo no Google Play Console](#4-criação-do-aplicativo-no-google-play-console)
5. [Declaração de Segurança dos Dados (Data Safety)](#5-declaração-de-segurança-dos-dados-data-safety)
6. [Declaração e Justificativa de Permissões Sensíveis](#6-declaração-e-justificativa-de-permissões-sensíveis)
7. [Ficha da Loja (Store Listing) e Recursos Gráficos](#7-ficha-da-loja-store-listing-e-recursos-gráficos)
8. [Lançamento e Faixas de Distribuição](#8-lançamento-e-faixas-de-distribuição)

---

## 1. Pré-requisitos e Conta de Desenvolvedor

1. **Conta Ativa no Google Play Console:**
   * Acesse [Google Play Console](https://play.google.com/console/signup).
   * Registre sua conta de desenvolvedor efetuando o pagamento da taxa única de US$ 25.
   * Conclua a validação de identidade (documento pessoal ou CNPJ/D-U-N-S da empresa).
2. **Ambiente Técnico Configurado:**
   * Flutter SDK stable instalado (`flutter doctor -v`).
   * Java SDK 17 (Temurin ou OpenJDK) com utilitário `keytool` no `PATH`.
   * Repositório clonado e atualizado na branch `main`.

---

## 2. Geração da Chave Criptográfica de Produção (Upload Keystore)

A publicação na Google Play Store exige que o binário `.aab` seja assinado com uma chave de upload privada permanente.

Execute o comando abaixo no terminal para gerar a sua chave de assinatura:

```bash
keytool -genkey -v -keystore ~/sentinela-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias sentinela-upload
```

> [!CAUTION]
> **Segurança Crítica:**
> Guarde o arquivo `sentinela-upload-key.jks` e as senhas em um local seguro (gerenciador de senhas ou cofre criptografado). Se essa chave for perdida, não será possível atualizar o aplicativo na Google Play sem solicitar reset manual ao suporte da Google.

---

## 3. Configuração do `key.properties` e Build do App Bundle

### 3.1. Arquivo de Propriedades da Chave
Crie o arquivo `android/key.properties` (já blindado contra commits pelo `.gitignore`):

```properties
storePassword=SUA_SENHA_DO_KEYSTORE
keyPassword=SUA_SENHA_DA_CHAVE
keyAlias=sentinela-upload
storeFile=/caminho/absoluto/para/sentinela-upload-key.jks
```

### 3.2. Gerando o Pacote `.aab` Oficial
O formato obrigatório para envio à Google Play Store é o **Android App Bundle (.aab)**:

```bash
# Limpeza de artefatos anteriores e resolução de dependências
flutter clean
flutter pub get

# Validação prévia de integridade e qualidade
flutter analyze --fatal-infos
flutter test --coverage

# Geração do App Bundle de release
flutter build appbundle --release
```

O arquivo compilado e otimizado estará disponível em:
```
build/app/outputs/bundle/release/app-release.aab
```

---

## 4. Criação do Aplicativo no Google Play Console

1. No painel do Google Play Console, clique em **Criar app**.
2. Preencha os campos obrigatórios:
   * **Nome do App:** `Sentinela - Alerta de Radares & Velocímetro`
   * **Idioma padrão:** Português (Brasil) — `pt-BR`
   * **Tipo de aplicativo:** Aplicativo
   * **Modelo de monetização:** Gratuito
3. Aceite as declarações de políticas e confirme a criação.

---

## 5. Declaração de Segurança dos Dados (Data Safety)

O Sentinela foi desenvolvido sob o princípio estrito de **Privacidade Absoluta e Zero Telemetria**.

* **URL Oficial da Política de Privacidade:**
  ```
  https://thcborges.github.io/sentinela-radar/privacy/politica-de-privacidade.html
  ```

### Gabarito de Respostas do Formulário Data Safety:
Consulte a documentação em [`docs/privacy/google_play_data_safety.md`](file:///home/thcborges/repos/mapa-radar-re/docs/privacy/google_play_data_safety.md):

* **O aplicativo coleta ou compartilha algum dado de usuário?**  
  👉 **Não**.
* **Todos os dados de usuários são criptografados em trânsito?**  
  👉 **Sim** (downloads sob demanda de bases governamentais abertas via HTTPS).
* **Oferece mecanismo de solicitação de exclusão de dados?**  
  👉 **Sim** (limpeza local com 1 toque no painel de configurações ou desinstalação).
* **Localização precisa (`ACCESS_FINE_LOCATION`):**  
  * Coletada externamente? **Não**.  
  * Compartilhada? **Não**.  
  * Finalidade: Funcionalidade do aplicativo (`App functionality`).  
  * Processamento efêmero: **Sim** (estritamente na memória volátil RAM para exibição no velocímetro analítico).
* **Rastreamento e IDs:**  
  * **Nenhum** SDK de terceiros, GAID ou identificador de publicidade é coletado ou monitorado.

---

## 6. Declaração e Justificativa de Permissões Sensíveis

A Google Play exige justificativa detalhada para permissões automotivas em segundo plano e janela flutuante:

### 6.1. Localização em Segundo Plano (`ACCESS_BACKGROUND_LOCATION`) e Foreground Service (`FOREGROUND_SERVICE_LOCATION`)
* **Finalidade:** O aplicativo opera como assistente de condução veicular contínuo para alerta antecipado de segurança viária (aproximação de radares de velocidade, fiscalização semafórica e lombadas físicas/eletrônicas).
* **Justificativa de Segundo Plano:** Os alertas auditivos e táteis precisam continuar ativos enquanto o motorista navega utilizando outros aplicativos em primeiro plano (ex: Waze, Google Maps ou Uber).
* **Vídeo Obrigatório:** Grave um vídeo demonstrativo de 1 a 2 minutos com o celular em modo de direção veicular demonstrando a transição do app para segundo plano / janela flutuante e o disparo de um alerta sonoro de radar.

### 6.2. Janela Flutuante (`SYSTEM_ALERT_WINDOW`)
* **Finalidade:** Exibição do card flutuante minimizado (Overlay HUD M3) contendo o velocímetro digital de alta precisão e sonar de aproximação sobrepostos a outros aplicativos de navegação.

---

## 7. Ficha da Loja (Store Listing) e Recursos Gráficos

### 7.1. Textos da Ficha
* **Nome do App (até 30 caracteres):**  
  `Sentinela: Radar e Velocímetro`
* **Breve Descrição (até 80 caracteres):**  
  `Alerta antecipado de radares, semáforos e lombadas 100% offline no Brasil.`
* **Descrição Completa:**  
  Destacar os 5 pilares do Sentinela:
  1. **100% Offline-First:** Toda a base de POIs (~70.000 pontos com índice espacial SQLite R*Tree) opera sem internet.
  2. **Velocímetro Digital Analítico:** Tipografia monoespaçada tabular de alto contraste Material Design 3 Dark HUD.
  3. **Sonar Circular 360°:** Visualização angular com alerta de proximidade e gradiente de profundidade.
  4. **Modo Janela Flutuante (Overlay):** Operação contínua sobreposta a navegadores como Waze e Google Maps.
  5. **Privacidade Absoluta:** Zero telemetria, sem necessidade de login e sem envio de coordenadas para servidores.

### 7.2. Ativos Visuais Obrigatórios
* **Ícone do Aplicativo:** 512 × 512 px (PNG de 32 bits, com canal alfa, até 1 MB).
* **Gráfico de Recursos (Feature Graphic):** 1024 × 500 px (JPEG ou PNG de 24 bits, sem transparência, até 15 MB).
* **Capturas de Tela (Screenshots de Celular):** No mínimo 2 e no máximo 8 imagens (proporção 16:9 ou 9:16, resolução mínima de 1080 px no lado menor). Recomenda-se incluir telas do HUD com velocímetro, sonar ativo e tela de preferências.

---

## 8. Lançamento e Faixas de Distribuição

1. No menu lateral do Play Console, selecione **Produção** (ou **Teste Fechado** se a sua conta for de pessoa física recente sujeita aos 20 testadores por 14 dias).
2. Clique em **Criar nova versão**.
3. Faça o upload do arquivo `app-release.aab` gerado.
4. Preencha as **Notas da Versão** (Release Notes):
   ```text
   - Lançamento oficial do Sentinela Radar v1.0.1.
   - Detecção offline de radares, lombadas, semáforos e pórticos Free Flow em todo o Brasil.
   - Velocímetro analítico de alta legibilidade Material Design 3 Dark HUD.
   - Modo Janela Flutuante (Overlay) compatível com Waze e Google Maps.
   - Privacidade absoluta: processamento 100% local sem telemetria.
   ```
5. Clique em **Salvar** ➔ **Revisar versão** ➔ **Iniciar lançamento**.
6. A Google Play realizará a análise de segurança e conformidade de políticas em um prazo típico de **24 a 72 horas úteis**.
