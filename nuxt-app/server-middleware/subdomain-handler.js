/**
 * Middleware для обработки запросов от поддоменов, которые были перенаправлены на /i/
 */
export default function (req, res, next) {
  // Получаем информацию о пути из URL
  const url = new URL(req.url, `http://${req.headers.host}`);
  const pathParts = url.pathname.split('/').filter(Boolean);
  
  // Мы ожидаем, что запросы будут в формате /i/[subdomain]/[path]
  if (pathParts[0] === 'i' && pathParts.length > 1) {
    const subdomain = pathParts[1];
    
    // Сохраняем информацию о поддомене в объекте запроса для использования в компонентах
    req.subdomain = subdomain;
    
    // Удаляем поддомен из пути, т.к. он уже обработан как параметр
    // Например, /i/mail/inbox -> /i/inbox
    if (pathParts.length > 2) {
      const newPath = '/i/' + pathParts.slice(2).join('/');
      url.pathname = newPath;
      req.url = url.pathname + url.search;
    }
    
    console.log(`Обработка запроса от поддомена: ${subdomain}, новый путь: ${req.url}`);
  } else if (pathParts[0] === 'i' && pathParts.length === 1) {
    // Если просто /i/ без поддомена, покажем список сервисов
    console.log('Запрос к списку сервисов');
  }
  
  // Также можно добавить информацию из заголовков, если перенаправление сделано через Nginx
  const originalHost = req.headers['x-original-host'];
  if (originalHost && originalHost !== 'canfly.org') {
    // Извлекаем поддомен из заголовка
    const subdomainFromHeader = originalHost.replace('.canfly.org', '');
    req.subdomainFromHeader = subdomainFromHeader;
  }
  
  next();
} 