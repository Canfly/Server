<template>
  <div class="service-container">
    <div class="service-header">
      <nuxt-link to="/i" class="back-button">← Все сервисы</nuxt-link>
      <h1>{{ serviceName }}</h1>
    </div>
    
    <div v-if="serviceExists" class="service-content">
      <div class="service-info">
        <p>Вы открыли сервис <strong>{{ $route.params.service }}</strong>.</p>
        <p>В полной версии здесь будет отображаться содержимое данного сервиса.</p>
        <p>Этот сервис также доступен по ссылке: <a :href="subdomainUrl" target="_blank">{{ subdomainUrl }}</a></p>
      </div>
      
      <div class="service-mock">
        <h2>Демо-интерфейс</h2>
        <div class="mock-ui">
          <div class="mock-sidebar">
            <div v-for="(item, index) in mockSidebarItems" :key="index" class="mock-sidebar-item">
              {{ item }}
            </div>
          </div>
          <div class="mock-content">
            <div class="mock-header"></div>
            <div class="mock-body">
              <div v-for="i in 4" :key="i" class="mock-item"></div>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <div v-else class="service-not-found">
      <h2>Сервис не найден</h2>
      <p>Запрошенный сервис "{{ $route.params.service }}" не существует или недоступен.</p>
      <nuxt-link to="/i" class="back-link">Вернуться к списку сервисов</nuxt-link>
    </div>
  </div>
</template>

<script>
export default {
  data() {
    return {
      availableServices: ['mail', 'chat', 'docs', 'calendar', 'drive'],
      serviceNames: {
        mail: 'Почтовый сервис',
        chat: 'Мессенджер',
        docs: 'Документы',
        calendar: 'Календарь',
        drive: 'Облачное хранилище'
      },
      mockSidebarItems: ['Элемент 1', 'Элемент 2', 'Элемент 3', 'Элемент 4', 'Элемент 5']
    };
  },
  computed: {
    serviceExists() {
      return this.availableServices.includes(this.$route.params.service);
    },
    serviceName() {
      const service = this.$route.params.service;
      return this.serviceNames[service] || service;
    },
    subdomainUrl() {
      return `https://${this.$route.params.service}.canfly.org`;
    }
  },
  head() {
    return {
      title: this.serviceExists 
        ? `CanFly - ${this.serviceName}` 
        : 'Сервис не найден'
    };
  }
};
</script>

<style scoped>
.service-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

.service-header {
  margin-bottom: 2rem;
  display: flex;
  flex-direction: column;
}

.back-button {
  display: inline-block;
  margin-bottom: 1rem;
  color: #3498db;
  text-decoration: none;
  font-weight: 500;
}

h1 {
  color: #2c3e50;
}

.service-content {
  display: grid;
  grid-template-columns: 1fr;
  gap: 2rem;
}

@media (min-width: 768px) {
  .service-content {
    grid-template-columns: 1fr 2fr;
  }
}

.service-info {
  background: #fff;
  padding: 1.5rem;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.service-mock {
  background: #fff;
  padding: 1.5rem;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.mock-ui {
  display: flex;
  height: 400px;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  overflow: hidden;
  margin-top: 1rem;
}

.mock-sidebar {
  width: 200px;
  background-color: #f5f5f5;
  padding: 1rem;
  border-right: 1px solid #e0e0e0;
}

.mock-sidebar-item {
  padding: 0.75rem 1rem;
  margin-bottom: 0.5rem;
  background-color: #fff;
  border-radius: 4px;
  cursor: pointer;
  transition: background-color 0.2s;
}

.mock-sidebar-item:hover {
  background-color: #e3f2fd;
}

.mock-content {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.mock-header {
  height: 60px;
  background-color: #f9f9f9;
  border-bottom: 1px solid #e0e0e0;
}

.mock-body {
  flex: 1;
  padding: 1rem;
  overflow-y: auto;
}

.mock-item {
  height: 80px;
  background-color: #f5f5f5;
  margin-bottom: 1rem;
  border-radius: 4px;
}

.service-not-found {
  text-align: center;
  background: #fff;
  padding: 3rem;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.back-link {
  display: inline-block;
  margin-top: 1rem;
  padding: 0.5rem 1rem;
  background-color: #3498db;
  color: white;
  text-decoration: none;
  border-radius: 4px;
  font-weight: 500;
}
</style> 