---
layout: home

hero:
  name: "Sentinela"
  text: "Alerta Inteligente de Radares"
  tagline: "Aplicativo móvel 100% offline-first em Flutter para alerta antecipado de radares, semáforos, lombadas e pedágios no Brasil."
  actions:
    - theme: brand
      text: Comece Agora
      link: /guide/introducao
    - theme: alt
      text: Ver Arquitetura
      link: /guide/arquitetura

features:
  - icon: 🛡️
    title: 100% Offline-First
    details: Mais de 70.000 pontos com índice espacial nativo SQLite R*Tree (~15-18MB) operando localmente sem consumir dados móveis.
  - icon: 🔄
    title: Atualização In-App Sob Demanda
    details: Sincronização direta com OpenStreetMap e dados abertos em Isolate Dart com tabelas de staging e swap atômico seguro.
  - icon: 🔒
    title: Privacidade Absoluta
    details: O sinal e processamento de GPS acontecem estritamente na memória volátil do dispositivo. Nenhuma coordenada é transmitida para a nuvem.
  - icon: 🪟
    title: Janela Flutuante (Overlay)
    details: Miniatura compacta translúcida sobreposta a navegadores como Waze e Google Maps, com velocímetro, sonar e distância regressiva.
  - icon: 🔊
    title: Áudio & Voz TTS Offline
    details: Síntese de voz especializada por tipo de ponto e bipes de proximidade com cadência progressiva proporcional à distância.
  - icon: 🧪
    title: Cobertura BDD/TDD ≥ 90%
    details: Mais de 110 testes herméticos unitários, de widget e integração, com verificação de segurança remota pelo Trivy.
---
