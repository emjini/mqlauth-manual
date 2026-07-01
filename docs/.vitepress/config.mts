import { defineConfig } from 'vitepress'
import sidebar from './sidebar.json'

export default defineConfig({
  lang: 'ja-JP',
  title: 'MQLAuth マニュアル',
  titleTemplate: ':title | MQLAuth マニュアル',
  description: 'MT4/MT5用EA・インジケーター認証サービス MQLAuth のドキュメントサイト',
  base: '/',
  cleanUrls: true,
  lastUpdated: true,
  head: [
    ['meta', { name: 'theme-color', content: '#3B82F6' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:locale', content: 'ja_JP' }],
    ['meta', { property: 'og:site_name', content: 'MQLAuth マニュアル' }],
  ],
  themeConfig: {
    logo: undefined,
    siteTitle: 'MQLAuth マニュアル',

    nav: [
      { text: 'ホーム', link: '/' },
      { text: '基本マニュアル', link: '/manual/' },
      { text: 'リファレンス', link: '/reference/' },
      { text: '応用マニュアル', link: '/advanced/' },
      { text: 'MQLAuth本サイト', link: 'https://mql-auth.com/' },
    ],

    sidebar,

    socialLinks: [
      { icon: 'x', link: 'https://twitter.com/MQLAuth' },
    ],

    search: {
      provider: 'local',
      options: {
        locales: {
          root: {
            translations: {
              button: {
                buttonText: 'ドキュメントを検索',
                buttonAriaLabel: 'ドキュメントを検索',
              },
              modal: {
                displayDetails: '詳細を表示',
                resetButtonTitle: 'クリア',
                backButtonTitle: '戻る',
                noResultsText: '結果が見つかりません',
                footer: {
                  selectText: '選択',
                  navigateText: '移動',
                  closeText: '閉じる',
                },
              },
            },
          },
        },
      },
    },

    docFooter: {
      prev: '前のページ',
      next: '次のページ',
    },

    outline: {
      label: 'このページの内容',
      level: [2, 3],
    },

    lastUpdated: {
      text: '最終更新',
      formatOptions: {
        dateStyle: 'long',
      },
    },

    footer: {
      message: 'MQLAuth マニュアル',
      copyright: '© 2020-2026 MQLAuth. All rights reserved.',
    },

    darkModeSwitchLabel: 'テーマ切替',
    lightModeSwitchTitle: 'ライトモード',
    darkModeSwitchTitle: 'ダークモード',
    returnToTopLabel: 'ページ上部へ',
    sidebarMenuLabel: 'メニュー',
  },
})
