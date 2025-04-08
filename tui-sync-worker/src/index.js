/**
 * Welcome to TUI Portfolio Sync Worker!
 * This worker handles synchronization between TUI iOS app and Cloudflare.
 */

// 导入工具函数
import { jsonResponse, handleOptions, verifyApiKey } from './utils/helpers.js';

// 导入路由处理函数
import { handleHome, handlePhotoDetail } from './routes/web.js';
import { 
  handleApiDocs, 
  handleGetPhotos, 
  handleGetPhoto, 
  handleGetPhotoCount, 
  handleHelloWorld 
} from './routes/api.js';
import { handleGetFile } from './routes/files.js';
import {
  handleInitSync,
  handleIncrementalSync,
  handleDatabaseSync,
  handleFileUpload,
  handleSyncStatus,
  handleVerifySync
} from './routes/sync.js';

// 定义静态路由
const routes = {
  // 网页路由
  'GET /': handleHome,
  'GET /api': handleApiDocs,
  
  // 基本API路由
  'GET /api/hello': handleHelloWorld,
  'GET /api/photos': handleGetPhotos,
  'GET /api/photos/count': handleGetPhotoCount,
  
  // 同步API路由
  'POST /api/sync/initialize': handleInitSync,
  'POST /api/sync/incremental': handleIncrementalSync,
  'POST /api/sync/database': handleDatabaseSync,
  'POST /api/sync/file': handleFileUpload,
  'GET /api/sync/status': handleSyncStatus,
  'POST /api/sync/verify': handleVerifySync,
};

// 定义动态路由
const dynamicRoutes = [
  {
    pattern: /^\/api\/photos\/([^\/]+)$/,
    method: 'GET',
    handler: async (request, env, matches) => {
      const id = matches[1];
      return await handleGetPhoto(request, env, id);
    }
  },
  // 照片详情页面路由
  {
    pattern: /^\/photo\/([^\/]+)$/,
    method: 'GET',
    handler: async (request, env, matches) => {
      const id = matches[1];
      return await handlePhotoDetail(request, env, id);
    }
  },
  // 文件访问路由
  {
    pattern: /^\/api\/files\/(.+)$/,
    method: 'GET',
    handler: async (request, env, matches) => {
      const filePath = matches[1];
      return await handleGetFile(request, env, filePath);
    }
  }
];

// 主入口函数
export default {
  async fetch(request, env, ctx) {
    try {
      // 处理CORS预检请求
      if (request.method === 'OPTIONS') {
        return handleOptions(request);
      }

      const url = new URL(request.url);
      const path = url.pathname;
      const routeKey = `${request.method} ${path}`;
      
      // 处理同步API验证
      if (path.startsWith('/api/sync/') && request.method !== 'OPTIONS') {
        const isValid = await verifyApiKey(request, env);
        if (!isValid) {
          return jsonResponse({ error: 'Unauthorized. Invalid API key.' }, 401);
        }
      }

      // 处理静态路由
      const handler = routes[routeKey];
      if (handler) {
        return await handler(request, env, ctx);
      }

      // 处理动态路由
      for (const route of dynamicRoutes) {
        if (request.method === route.method) {
          const matches = path.match(route.pattern);
          if (matches) {
            return await route.handler(request, env, matches);
          }
        }
      }

      // 如果没有匹配的路由，返回404
      return new Response('Not Found', {
        status: 404,
        headers: { 'Access-Control-Allow-Origin': '*' }
      });
    } catch (error) {
      console.error('Server error:', error);
      return new Response(`Server Error: ${error.message}`, {
        status: 500,
        headers: { 'Access-Control-Allow-Origin': '*' }
      });
    }
  }
};