/**
 * 同步功能路由处理函数
 */

import { jsonResponse, generateId, getCurrentTimestamp, calculateDiff, logSync } from '../utils/helpers.js';

/**
 * 处理初始化同步请求
 * @param {Request} request - 请求对象
 * @param {Object} env - 环境变量
 * @param {Object} ctx - 上下文对象
 * @returns {Response} - JSON响应
 */
export async function handleInitSync(request, env, ctx) {
  try {
    const data = await request.json();
    const { deviceId, userName } = data;

    if (!deviceId || !userName) {
      return jsonResponse({
        success: false,
        error: 'Missing required fields'
      }, 400);
    }

    // 清除已有的同步记录
    await clearSyncRecords(env, deviceId);

    // 创建新的同步会话
    const syncId = generateId();
    const timestamp = getCurrentTimestamp();

    await createSyncSession(env, syncId, deviceId, userName, timestamp);

    // 记录日志
    await logSync(env, 'initialize', 'started', { deviceId, userName, syncId });

    return jsonResponse({
      success: true,
      syncId,
      timestamp,
      message: 'Sync initialization successful'
    });
  } catch (error) {
    console.error('Initialize sync error:', error);
    return jsonResponse({
      success: false,
      error: `Initialize sync failed: ${error.message}`
    }, 500);
  }
}

/**
 * 处理增量同步请求
 * @param {Request} request - 请求对象
 * @param {Object} env - 环境变量
 * @param {Object} ctx - 上下文对象
 * @returns {Response} - JSON响应
 */
export async function handleIncrementalSync(request, env, ctx) {
  try {
    const data = await request.json();
    const { deviceId, lastSyncTime } = data;

    if (!deviceId || !lastSyncTime) {
      return jsonResponse({
        success: false,
        error: 'Missing required fields'
      }, 400);
    }

    // 获取上次同步后的变更
    const changes = await getChangesSinceLastSync(env, lastSyncTime);

    // 创建新的同步会话
    const syncId = generateId();
    const timestamp = getCurrentTimestamp();

    await updateSyncSession(env, syncId, deviceId, timestamp);

    // 记录日志
    await logSync(env, 'incremental', 'completed', { 
      deviceId, 
      syncId, 
      itemsChanged: changes.length 
    });

    return jsonResponse({
      success: true,
      syncId,
      timestamp,
      changes,
      message: 'Incremental sync successful'
    });
  } catch (error) {
    console.error('Incremental sync error:', error);
    return jsonResponse({
      success: false,
      error: `Incremental sync failed: ${error.message}`
    }, 500);
  }
}

/**
 * 处理数据库同步请求
 * @param {Request} request - 请求对象
 * @param {Object} env - 环境变量
 * @param {Object} ctx - 上下文对象
 * @returns {Response} - JSON响应
 */
export async function handleDatabaseSync(request, env, ctx) {
  try {
    const data = await request.json();
    const { syncId, photos, isIncremental = false } = data;

    if (!syncId || !Array.isArray(photos)) {
      return jsonResponse({
        success: false,
        error: 'Missing required fields or invalid data format'
      }, 400);
    }

    // 验证同步会话
    const isValidSession = await validateSyncSession(env, syncId);
    if (!isValidSession) {
      return jsonResponse({
        success: false,
        error: 'Invalid sync session'
      }, 400);
    }

    // 处理照片数据
    const result = await processPhotosData(env, photos, isIncremental);

    // 更新同步状态
    await updateSyncStatus(env, syncId, 'database', 'completed', result);

    // 记录日志
    await logSync(env, 'database_sync', 'completed', { 
      syncId, 
      isIncremental,
      processed: result.processed,
      added: result.added,
      updated: result.updated,
      errors: result.errors.length
    });

    return jsonResponse({
      success: true,
      processed: result.processed,
      added: result.added,
      updated: result.updated,
      errors: result.errors,
      message: 'Database sync successful'
    });
  } catch (error) {
    console.error('Database sync error:', error);
    return jsonResponse({
      success: false,
      error: `Database sync failed: ${error.message}`
    }, 500);
  }
}

/**
 * 处理文件上传请求
 * @param {Request} request - 请求对象
 * @param {Object} env - 环境变量
 * @param {Object} ctx - 上下文对象
 * @returns {Response} - JSON响应
 */
export async function handleFileUpload(request, env, ctx) {
  try {
    const formData = await request.formData();
    const syncId = formData.get('syncId');
    const filePath = formData.get('filePath');
    const fileData = formData.get('file');
    
    if (!syncId || !filePath || !fileData) {
      return jsonResponse({
        success: false,
        error: 'Missing required fields'
      }, 400);
    }

    // 验证同步会话
    const isValidSession = await validateSyncSession(env, syncId);
    if (!isValidSession) {
      return jsonResponse({
        success: false,
        error: 'Invalid sync session'
      }, 400);
    }

    // 上传文件到R2存储桶
    const result = await uploadFileToR2(env, filePath, fileData);

    // 更新同步状态
    await updateSyncStatus(env, syncId, 'file', result.success ? 'completed' : 'failed', {
      filePath,
      size: fileData.size
    });

    // 记录日志
    await logSync(env, 'file_upload', result.success ? 'completed' : 'failed', { 
      syncId, 
      filePath,
      size: fileData.size
    });

    return jsonResponse({
      success: result.success,
      filePath,
      message: result.success ? 'File uploaded successfully' : 'File upload failed',
      error: result.error
    });
  } catch (error) {
    console.error('File upload error:', error);
    return jsonResponse({
      success: false,
      error: `File upload failed: ${error.message}`
    }, 500);
  }
}

/**
 * 处理同步状态查询请求
 * @param {Request} request - 请求对象
 * @param {Object} env - 环境变量
 * @param {Object} ctx - 上下文对象
 * @returns {Response} - JSON响应
 */
export async function handleSyncStatus(request, env, ctx) {
  try {
    const url = new URL(request.url);
    const syncId = url.searchParams.get('syncId');
    const deviceId = url.searchParams.get('deviceId');

    if (!syncId && !deviceId) {
      return jsonResponse({
        success: false,
        error: 'Either syncId or deviceId is required'
      }, 400);
    }

    let status;
    if (syncId) {
      // 获取指定同步会话的状态
      status = await getSyncStatus(env, syncId);
    } else {
      // 获取设备的最后同步状态
      status = await getDeviceLastSyncStatus(env, deviceId);
    }

    if (!status) {
      return jsonResponse({
        success: false,
        error: 'No sync status found'
      }, 404);
    }

    return jsonResponse({
      success: true,
      status
    });
  } catch (error) {
    console.error('Sync status error:', error);
    return jsonResponse({
      success: false,
      error: `Failed to get sync status: ${error.message}`
    }, 500);
  }
}

/**
 * 处理同步验证请求
 * @param {Request} request - 请求对象
 * @param {Object} env - 环境变量
 * @param {Object} ctx - 上下文对象
 * @returns {Response} - JSON响应
 */
export async function handleVerifySync(request, env, ctx) {
  try {
    const data = await request.json();
    const { photoIds, syncId } = data;

    if (!syncId || !Array.isArray(photoIds)) {
      return jsonResponse({
        success: false,
        error: 'Missing required fields'
      }, 400);
    }

    // 验证同步会话
    const isValidSession = await validateSyncSession(env, syncId);
    if (!isValidSession) {
      return jsonResponse({
        success: false,
        error: 'Invalid sync session'
      }, 400);
    }

    // 验证照片同步状态
    const results = await verifyPhotoSync(env, photoIds);

    return jsonResponse({
      success: true,
      results,
      summary: {
        total: photoIds.length,
        found: results.filter(r => r.exists).length,
        missing: results.filter(r => !r.exists).length
      }
    });
  } catch (error) {
    console.error('Verify sync error:', error);
    return jsonResponse({
      success: false,
      error: `Verify sync failed: ${error.message}`
    }, 500);
  }
}

// ================= 辅助函数 =================

/**
 * 清除同步记录
 * @param {Object} env - 环境变量
 * @param {string} deviceId - 设备ID
 * @returns {Promise<void>}
 */
async function clearSyncRecords(env, deviceId) {
  // 仅清除该设备的未完成同步记录，保留历史记录
  const stmt = env.data.prepare(
    `UPDATE SyncSessions 
     SET status = 'cancelled', 
         endTimestamp = ? 
     WHERE deviceId = ? AND status = 'in_progress'`
  );
  
  await stmt.bind(getCurrentTimestamp(), deviceId).run();
}

/**
 * 创建同步会话
 * @param {Object} env - 环境变量
 * @param {string} syncId - 同步ID
 * @param {string} deviceId - 设备ID
 * @param {string} userName - 用户名
 * @param {string} timestamp - 时间戳
 * @returns {Promise<void>}
 */
async function createSyncSession(env, syncId, deviceId, userName, timestamp) {
  const stmt = env.data.prepare(
    `INSERT INTO SyncSessions (id, deviceId, userName, startTimestamp, status) 
     VALUES (?, ?, ?, ?, ?)`
  );
  
  await stmt.bind(syncId, deviceId, userName, timestamp, 'in_progress').run();
}

/**
 * 更新同步会话
 * @param {Object} env - 环境变量
 * @param {string} syncId - 同步ID
 * @param {string} deviceId - 设备ID
 * @param {string} timestamp - 时间戳
 * @returns {Promise<void>}
 */
async function updateSyncSession(env, syncId, deviceId, timestamp) {
  const stmt = env.data.prepare(
    `INSERT INTO SyncSessions (id, deviceId, startTimestamp, status) 
     VALUES (?, ?, ?, ?)`
  );
  
  await stmt.bind(syncId, deviceId, timestamp, 'in_progress').run();
}

/**
 * 验证同步会话
 * @param {Object} env - 环境变量
 * @param {string} syncId - 同步ID
 * @returns {Promise<boolean>}
 */
async function validateSyncSession(env, syncId) {
  const stmt = env.data.prepare(
    `SELECT id FROM SyncSessions WHERE id = ? AND status = 'in_progress'`
  );
  
  const result = await stmt.bind(syncId).first();
  return !!result;
}

/**
 * 获取上次同步后的变更
 * @param {Object} env - 环境变量
 * @param {string} lastSyncTime - 上次同步时间
 * @returns {Promise<Array>}
 */
async function getChangesSinceLastSync(env, lastSyncTime) {
  const stmt = env.data.prepare(
    `SELECT * FROM Photos WHERE addTimestamp > ? OR modifiedTimestamp > ?`
  );
  
  const result = await stmt.bind(lastSyncTime, lastSyncTime).all();
  return result.results || [];
}

/**
 * 处理照片数据
 * @param {Object} env - 环境变量
 * @param {Array} photos - 照片数据数组
 * @param {boolean} isIncremental - 是否为增量同步
 * @returns {Promise<Object>}
 */
async function processPhotosData(env, photos, isIncremental) {
  const result = {
    processed: photos.length,
    added: 0,
    updated: 0,
    errors: []
  };

  for (const photo of photos) {
    try {
      // 检查照片是否已存在
      const existingPhoto = await getPhotoById(env, photo.Id);
      
      if (!existingPhoto) {
        // 添加新照片
        await addPhoto(env, photo);
        result.added++;
      } else if (isIncremental) {
        // 更新现有照片
        await updatePhoto(env, photo);
        result.updated++;
      }
    } catch (error) {
      result.errors.push({
        id: photo.Id,
        error: error.message
      });
    }
  }

  return result;
}

/**
 * 根据ID获取照片
 * @param {Object} env - 环境变量
 * @param {string} id - 照片ID
 * @returns {Promise<Object>}
 */
async function getPhotoById(env, id) {
  const stmt = env.data.prepare(`SELECT Id FROM Photos WHERE Id = ?`);
  return await stmt.bind(id).first();
}

/**
 * 添加新照片
 * @param {Object} env - 环境变量
 * @param {Object} photo - 照片数据
 * @returns {Promise<void>}
 */
async function addPhoto(env, photo) {
  // 构建插入语句
  const fields = Object.keys(photo).join(', ');
  const placeholders = Object.keys(photo).map(() => '?').join(', ');
  
  const stmt = env.data.prepare(
    `INSERT INTO Photos (${fields}) VALUES (${placeholders})`
  );
  
  // 绑定所有值
  const values = Object.values(photo);
  await stmt.bind(...values).run();
}

/**
 * 更新照片
 * @param {Object} env - 环境变量
 * @param {Object} photo - 照片数据
 * @returns {Promise<void>}
 */
async function updatePhoto(env, photo) {
  // 构建更新语句
  const fields = Object.keys(photo)
    .filter(key => key !== 'Id')
    .map(key => `${key} = ?`)
    .join(', ');
  
  const stmt = env.data.prepare(
    `UPDATE Photos SET ${fields}, modifiedTimestamp = ? WHERE Id = ?`
  );
  
  // 绑定所有值
  const values = Object.keys(photo)
    .filter(key => key !== 'Id')
    .map(key => photo[key]);
  
  await stmt.bind(...values, getCurrentTimestamp(), photo.Id).run();
}

/**
 * 上传文件到R2存储桶
 * @param {Object} env - 环境变量
 * @param {string} filePath - 文件路径
 * @param {Blob} fileData - 文件数据
 * @returns {Promise<Object>}
 */
async function uploadFileToR2(env, filePath, fileData) {
  try {
    // 设置适当的Content-Type
    let contentType = 'application/octet-stream';
    if (filePath.endsWith('.jpg') || filePath.endsWith('.jpeg')) {
      contentType = 'image/jpeg';
    } else if (filePath.endsWith('.png')) {
      contentType = 'image/png';
    } else if (filePath.endsWith('.gif')) {
      contentType = 'image/gif';
    } else if (filePath.endsWith('.webp')) {
      contentType = 'image/webp';
    }

    // 上传到R2存储桶
    await env.images.put(filePath, fileData, {
      httpMetadata: {
        contentType: contentType
      }
    });

    return {
      success: true
    };
  } catch (error) {
    console.error('R2 upload error:', error);
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * 更新同步状态
 * @param {Object} env - 环境变量
 * @param {string} syncId - 同步ID
 * @param {string} operation - 操作类型
 * @param {string} status - 状态
 * @param {Object} details - 详细信息
 * @returns {Promise<void>}
 */
async function updateSyncStatus(env, syncId, operation, status, details) {
  const stmt = env.data.prepare(
    `INSERT INTO SyncOperations (syncId, operation, status, details, timestamp) 
     VALUES (?, ?, ?, ?, ?)`
  );
  
  await stmt.bind(
    syncId,
    operation,
    status,
    JSON.stringify(details),
    getCurrentTimestamp()
  ).run();
}

/**
 * 获取同步状态
 * @param {Object} env - 环境变量
 * @param {string} syncId - 同步ID
 * @returns {Promise<Object>}
 */
async function getSyncStatus(env, syncId) {
  // 获取同步会话
  const sessionStmt = env.data.prepare(
    `SELECT * FROM SyncSessions WHERE id = ?`
  );
  const session = await sessionStmt.bind(syncId).first();
  
  if (!session) {
    return null;
  }

  // 获取同步操作
  const operationsStmt = env.data.prepare(
    `SELECT * FROM SyncOperations WHERE syncId = ? ORDER BY timestamp ASC`
  );
  const operations = await operationsStmt.bind(syncId).all();

  return {
    session,
    operations: operations.results || []
  };
}

/**
 * 获取设备最后同步状态
 * @param {Object} env - 环境变量
 * @param {string} deviceId - 设备ID
 * @returns {Promise<Object>}
 */
async function getDeviceLastSyncStatus(env, deviceId) {
  // 获取最后一个同步会话
  const sessionStmt = env.data.prepare(
    `SELECT * FROM SyncSessions 
     WHERE deviceId = ? 
     ORDER BY startTimestamp DESC 
     LIMIT 1`
  );
  const session = await sessionStmt.bind(deviceId).first();
  
  if (!session) {
    return null;
  }

  // 获取同步操作
  const operationsStmt = env.data.prepare(
    `SELECT * FROM SyncOperations 
     WHERE syncId = ? 
     ORDER BY timestamp ASC`
  );
  const operations = await operationsStmt.bind(session.id).all();

  return {
    session,
    operations: operations.results || []
  };
}

/**
 * 验证照片同步状态
 * @param {Object} env - 环境变量
 * @param {Array} photoIds - 照片ID数组
 * @returns {Promise<Array>}
 */
async function verifyPhotoSync(env, photoIds) {
  const results = [];

  for (const id of photoIds) {
    // 检查数据库中是否存在照片
    const photoExists = await getPhotoById(env, id);
    
    // 检查R2中是否存在文件
    let fileExists = false;
    if (photoExists) {
      const photoPath = await getPhotoPath(env, id);
      if (photoPath) {
        fileExists = await checkFileExists(env, photoPath);
      }
    }

    results.push({
      id,
      exists: !!photoExists,
      fileExists
    });
  }

  return results;
}

/**
 * 获取照片路径
 * @param {Object} env - 环境变量
 * @param {string} id - 照片ID
 * @returns {Promise<string>}
 */
async function getPhotoPath(env, id) {
    const stmt = env.data.prepare(`SELECT Path FROM Photos WHERE Id = ?`);
    const result = await stmt.bind(id).first();
    return result ? result.Path : null;
  }
  
  /**
   * 检查文件是否存在于R2
   * @param {Object} env - 环境变量
   * @param {string} path - 文件路径
   * @returns {Promise<boolean>}
   */
  async function checkFileExists(env, path) {
    try {
      const object = await env.images.head(path);
      return !!object;
    } catch (error) {
      return false;
    }
  }