export default {
  // Глобальные настройки страницы
  head: {
    title: 'CanFly - Сервисы',
    meta: [
      { charset: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { hid: 'description', name: 'description', content: 'CanFly - Микросервисы' }
    ],
    link: [
      { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' }
    ]
  },

  // Глобальный CSS
  css: [
  ],

  // Плагины, которые загружаются перед монтированием приложения
  plugins: [
  ],

  // Компоненты автоматически импортируются
  components: true,

  // Модули разработки
  buildModules: [
    '@nuxt/typescript-build',
  ],

  // Модули
  modules: [
  ],

  // Серверный посредник для обработки поддоменов
  serverMiddleware: [
    '~/server-middleware/subdomain-handler.js'
  ],

  // Настройки сервера
  server: {
    port: process.env.PORT || 3000,
    host: '0.0.0.0'
  },

  // Настройки сборки
  build: {
  }
} 