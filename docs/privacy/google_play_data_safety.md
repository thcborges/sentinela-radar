# Declaração Google Play Data Safety — Sentinela Radar

Este documento orienta o preenchimento da seção **Segurança dos Dados (Data Safety)** no Google Play Console para publicação oficial do Sentinela.

---

## 📋 Resumo das Respostas para o Formulário do Google Play Console

### 1. Coleta e Compartilhamento de Dados
* **O app coleta ou compartilha algum tipo de dado de usuário?**
  * Resposta: **Não**. (O app não coleta nem compartilha dados com terceiros ou com a nuvem).
* **Todos os dados de usuários coletados pelo app são criptografados em trânsito?**
  * Resposta: **Sim** (As rotinas opcionais de download de bases abertas via Wi-Fi utilizam protocolo HTTPS seguro).
* **Você oferece aos usuários uma forma de solicitar a exclusão dos dados?**
  * Resposta: **Sim** (O usuário pode apagar todo o histórico e pontos locais com 1 toque no painel de configurações ou desinstalando o app).

---

### 2. Detalhamento por Categoria de Dado

#### Localização (`Location`)
* **Localização aproximada:** Não coletada.
* **Localização precisa (`Precise Location`):**
  * Coletada? **Não** (Processamento em tempo real estritamente efêmero na RAM para exibição no velocímetro; não é transferida para fora do dispositivo).
  * Compartilhada? **Não**.
  * Finalidade: Funcionalidade do app (`App functionality`).
  * Processamento efêmero: **Sim**.

#### Informações Pessoais, Financeiras, Mensagens, Fotos, Áudio, Arquivos
* **Nenhum dado é coletado ou compartilhado.**

#### Identificadores do Dispositivo ou Outros IDs
* **Nenhum identificador de publicidade ou hardware é coletado ou rastreado.**
