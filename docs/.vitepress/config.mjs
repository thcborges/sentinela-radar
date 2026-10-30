import { defineConfig } from 'vitepress';

export default defineConfig({
  title: 'Sentinela',
  description: 'Alerta Inteligente de Radares, Semáforos e Pedágios 100% Offline-First',
  base: '/sentinela-radar/',
  lang: 'pt-BR',
  appearance: 'dark',

  themeConfig: {
    nav: [
      { text: 'Visão Geral', link: '/guide/introducao' },
      { text: 'Arquitetura', link: '/guide/arquitetura' },
      { text: 'Motor Geo & Alertas', link: '/guide/motor-alertas' },
      { text: 'Offline-First', link: '/guide/offline-first' },
      { text: 'Qualidade & BDD/TDD', link: '/guide/qualidade-testes' },
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Introdução & Pilares',
          items: [
            { text: 'Visão Geral do Produto', link: '/guide/introducao' },
            { text: 'Arquitetura do Sistema', link: '/guide/arquitetura' },
          ],
        },
        {
          text: 'Engenharia Offline & Dados',
          items: [
            { text: 'Estratégia Offline-First & SQLite R*Tree', link: '/guide/offline-first' },
            { text: 'Motor Matemático & Algoritmos de Alerta', link: '/guide/motor-alertas' },
          ],
        },
        {
          text: 'Qualidade de Software',
          items: [
            { text: 'Metodologia BDD/TDD & Cobertura ≥ 90%', link: '/guide/qualidade-testes' },
          ],
        },
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/thcborges/sentinela-radar' },
    ],

    footer: {
      message: 'Distribuído sob licença de código aberto. 100% Offline e Privado.',
      copyright: 'Copyright © 2026 Sentinela Radar',
    },
  },

  markdown: {
    math: true,
  },
});
