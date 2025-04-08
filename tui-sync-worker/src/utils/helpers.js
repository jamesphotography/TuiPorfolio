/**
 * 辅助函数集合
 */

/**
 * 创建标准JSON响应
 * @param {Object} data - 响应数据
 * @param {number} status - HTTP状态码
 * @returns {Response} - 格式化的JSON响应
 */
export function jsonResponse(data, status = 200) {
    return new Response(JSON.stringify(data), {
      status,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
  
  /**
   * 处理CORS预检请求
   * @param {Request} request - 请求对象
   * @returns {Response} - CORS响应
   */
  export function handleOptions(request) {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-API-Key',
        'Access-Control-Max-Age': '86400'
      }
    });
  }
  
  /**
   * 验证API密钥
   * @param {Request} request - 请求对象
   * @param {Object} env - 环境变量
   * @returns {boolean} - 验证是否通过
   */
  export async function verifyApiKey(request, env) {
    // 从请求头中获取API密钥
    const apiKey = request.headers.get('X-API-Key');
    if (!apiKey) {
      return false;
    }
  
    try {
      // 在实际应用中，使用D1数据库或KV存储验证API密钥
      // 这里为了简单，我们直接比较环境变量中的API_KEY
      return apiKey === env.API_KEY;
    } catch (error) {
      console.error('API Key verification error:', error);
      return false;
    }
  }
  
  /**
   * 获取当前时间戳
   * @returns {string} - ISO格式的时间戳
   */
  export function getCurrentTimestamp() {
    return new Date().toISOString();
  }
  
  /**
   * 生成唯一ID
   * @returns {string} - 唯一ID
   */
  export function generateId() {
    return crypto.randomUUID();
  }
  
  /**
   * 计算增量同步的文件
   * @param {Array} localFiles - 本地文件列表
   * @param {Array} remoteFiles - 远程文件列表
   * @returns {Object} - 需要添加和更新的文件
   */
  export function calculateDiff(localFiles, remoteFiles) {
    const remoteFilesMap = new Map();
    remoteFiles.forEach(file => {
      remoteFilesMap.set(file.path, file);
    });
  
    const filesToAdd = [];
    const filesToUpdate = [];
  
    localFiles.forEach(localFile => {
      const remotFile = remoteFilesMap.get(localFile.path);
      
      if (!remotFile) {
        filesToAdd.push(localFile);
      } else if (localFile.lastModified > remotFile.lastModified) {
        filesToUpdate.push(localFile);
      }
    });
  
    return {
      filesToAdd,
      filesToUpdate
    };
  }
  
  /**
   * 记录同步日志
   * @param {Object} env - 环境变量
   * @param {string} operation - 操作类型
   * @param {string} status - 状态
   * @param {Object} details - 详细信息
   * @returns {Promise<void>}
   */
  export async function logSync(env, operation, status, details = {}) {
    try {
      const log = {
        timestamp: getCurrentTimestamp(),
        operation,
        status,
        details
      };
  
      const stmt = env.data.prepare(
        `INSERT INTO SyncLogs (timestamp, operation, status, details) 
         VALUES (?, ?, ?, ?)`
      );
  
      await stmt.bind(
        log.timestamp,
        log.operation,
        log.status,
        JSON.stringify(log.details)
      ).run();
    } catch (error) {
      console.error('Failed to log sync:', error);
    }
  }