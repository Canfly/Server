<template>
  <div class="services-container">
    <h1>Сервисы CanFly</h1>
    
    <div class="services-grid">
      <div v-for="service in services" :key="service.id" class="service-card">
        <div class="service-icon" :class="service.icon"></div>
        <h2>{{ service.name }}</h2>
        <p>{{ service.description }}</p>
        <nuxt-link :to="`/i/${service.id}`" class="service-link">Открыть сервис</nuxt-link>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  data() {
    return {
      services: [
        {
          id: 'mail',
          name: 'Почта',
          description: 'Почтовый сервис CanFly',
          icon: 'mail-icon'
        },
        {
          id: 'chat',
          name: 'Чат',
          description: 'Мессенджер для общения',
          icon: 'chat-icon'
        },
        {
          id: 'docs',
          name: 'Документы',
          description: 'Совместная работа с документами',
          icon: 'docs-icon'
        },
        {
          id: 'calendar',
          name: 'Календарь',
          description: 'Планирование событий и встреч',
          icon: 'calendar-icon'
        },
        {
          id: 'drive',
          name: 'Диск',
          description: 'Облачное хранилище файлов',
          icon: 'drive-icon'
        }
      ]
    };
  },
  head() {
    return {
      title: 'CanFly - Все сервисы'
    };
  }
};
</script>

<style scoped>
.services-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

h1 {
  text-align: center;
  margin-bottom: 2rem;
  color: #2c3e50;
}

.services-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 2rem;
}

.service-card {
  background: #fff;
  border-radius: 8px;
  padding: 1.5rem;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.service-card:hover {
  transform: translateY(-5px);
  box-shadow: 0 12px 16px rgba(0, 0, 0, 0.1);
}

.service-icon {
  width: 60px;
  height: 60px;
  margin-bottom: 1rem;
  background-color: #f0f4f8;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

h2 {
  margin-bottom: 0.5rem;
  color: #2c3e50;
}

p {
  color: #606f7b;
  margin-bottom: 1.5rem;
}

.service-link {
  display: inline-block;
  padding: 0.5rem 1rem;
  background-color: #3498db;
  color: white;
  text-decoration: none;
  border-radius: 4px;
  font-weight: 500;
  transition: background-color 0.3s ease;
}

.service-link:hover {
  background-color: #2980b9;
}
</style> 