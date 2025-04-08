import Foundation

/// 用于根据用户配置生成CloudFlare Worker代码的工具类
class WorkerCodeGenerator {
    /// 生成Worker.js代码
    /// - Parameters:
    ///   - config: 用户的CloudFlare配置
    /// - Returns: 生成的Worker代码
    static func generateWorkerJS(config: CloudSyncConfiguration) -> String {
        return """
        /**
         * TUI Portfolio - 云同步Worker
         * 为 \(config.workerName).workers.dev 生成
         * 存储桶: \(config.r2BucketName)
         * 数据库: \(config.d1DatabaseName)
         * 
         * 这个Worker实现了TUI Portfolio应用的服务器端同步功能。
         * 它与iOS应用程序配合使用，通过R2存储照片文件，通过D1存储元数据。
         */

        // 绑定环境变量 - 在CloudFlare Dashboard中配置
        // - API_KEY: API验证密钥 (使用用户配置的令牌)
        // - BUCKET: R2存储桶名称 (使用\(config.r2BucketName))
        // - DB: D1数据库 (使用\(config.d1DatabaseName))

        /**
         * 路由处理
         */
        export default {
          async fetch(request, env, ctx) {
            // 允许CORS
            if (request.method === 'OPTIONS') {
              return handleCORS(request);
            }
            
            // 路由请求
            const url = new URL(request.url);
            const path = url.pathname;
            
            // 验证API密钥
            if (path !== '/health' && !isAuthorized(request, env)) {
              return new Response(JSON.stringify({ 
                success: false, 
                message: '未授权访问' 
              }), { 
                status: 401,
                headers: corsHeaders() 
              });
            }
            
            try {
              // API路由
              if (path === '/health') {
                return handleHealth();
              } else if (path === '/sync/initialize' && request.method === 'POST') {
                return handleInitializeSync(request, env);
              } else if (path === '/sync/records' && request.method === 'POST') {
                return handleSyncRecords(request, env);
              } else if (path === '/sync/files' && request.method === 'POST') {
                return handleSyncFiles(request, env);
              } else if (path === '/sync/finalize' && request.method === 'POST') {
                return handleFinalizeSync(request, env);
              }
              
              // 未找到的路由
              return new Response(JSON.stringify({ 
                success: false, 
                message: '未找到请求的API端点' 
              }), { 
                status: 404,
                headers: corsHeaders() 
              });
            } catch (error) {
              // 错误处理
              console.error(`处理请求错误: ${error.message}`);
              return new Response(JSON.stringify({ 
                success: false, 
                message: `服务器错误: ${error.message}` 
              }), { 
                status: 500,
                headers: corsHeaders() 
              });
            }
          }
        };

        /**
         * 处理健康检查请求
         */
        function handleHealth() {
          return new Response(JSON.stringify({ 
            success: true, 
            status: 'ok',
            version: '1.0.0',
            timestamp: new Date().toISOString() 
          }), { 
            status: 200,
            headers: corsHeaders() 
          });
        }

        /**
         * 处理初始化同步请求
         */
        async function handleInitializeSync(request, env) {
          const data = await request.json();
          const { forceFullSync, deviceId, appVersion, lastSyncTime } = data;
          
          // 创建同步会话ID
          const sessionId = crypto.randomUUID();
          const timestamp = new Date().toISOString();
          
          // 保存同步会话到数据库
          await env.DB.prepare(`
            INSERT INTO sync_sessions (id, device_id, app_version, start_time, status)
            VALUES (?, ?, ?, ?, ?)
          `)
          .bind(sessionId, deviceId, appVersion, timestamp, 'STARTED')
          .run();
          
          return new Response(JSON.stringify({ 
            success: true, 
            sessionId,
            message: '同步会话已初始化'
          }), { 
            status: 200,
            headers: corsHeaders() 
          });
        }

        /**
         * 处理同步记录请求
         */
        async function handleSyncRecords(request, env) {
          const data = await request.json();
          const { sessionId, records } = data;
          
          // 验证会话
          if (!await isValidSession(sessionId, env)) {
            return new Response(JSON.stringify({ 
              success: false, 
              message: '无效的同步会话' 
            }), { 
              status: 400,
              headers: corsHeaders() 
            });
          }
          
          // 处理结果
          const results = [];
          
          // 处理每个记录
          for (const record of records) {
            try {
              const { id, tableType, recordId, operationType, timestamp } = record;
              
              // 处理不同类型的操作
              if (tableType === 'Photos') {
                switch (operationType) {
                  case 'ADD':
                  case 'UPDATE':
                    // 标记记录为待处理，等待文件上传
                    await env.DB.prepare(`
                      INSERT OR REPLACE INTO sync_records 
                      (id, session_id, table_type, record_id, operation_type, timestamp, status, error_message)
                      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    `)
                    .bind(id, sessionId, tableType, recordId, operationType, timestamp, 'PENDING', null)
                    .run();
                    
                    results.push({
                      id,
                      success: true,
                      errorMessage: null
                    });
                    break;
                    
                  case 'DELETE':
                    // 对于删除操作，可以立即处理
                    await env.DB.prepare(`
                      DELETE FROM photos WHERE id = ?
                    `)
                    .bind(recordId)
                    .run();
                    
                    // 删除R2中的文件
                    try {
                      await env.BUCKET.delete(`photos/${recordId}.jpg`);
                      await env.BUCKET.delete(`thumbnails/${recordId}_thumb350.jpg`);
                    } catch (e) {
                      // 忽略不存在的文件错误
                      console.log(`删除文件时出错: ${e.message}`);
                    }
                    
                    await env.DB.prepare(`
                      INSERT OR REPLACE INTO sync_records 
                      (id, session_id, table_type, record_id, operation_type, timestamp, status, error_message)
                      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    `)
                    .bind(id, sessionId, tableType, recordId, operationType, timestamp, 'COMPLETED', null)
                    .run();
                    
                    results.push({
                      id,
                      success: true,
                      errorMessage: null
                    });
                    break;
                    
                  default:
                    throw new Error(`不支持的操作类型: ${operationType}`);
                }
              } else {
                throw new Error(`不支持的表类型: ${tableType}`);
              }
            } catch (error) {
              console.error(`处理记录错误 ${record.id}: ${error.message}`);
              
              try {
                // 更新记录状态为错误
                await env.DB.prepare(`
                  INSERT OR REPLACE INTO sync_records 
                  (id, session_id, table_type, record_id, operation_type, timestamp, status, error_message)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                `)
                .bind(record.id, sessionId, record.tableType, record.recordId, record.operationType, record.timestamp, 'ERROR', error.message)
                .run();
              } catch (dbError) {
                console.error(`更新记录状态失败: ${dbError.message}`);
              }
              
              results.push({
                id: record.id,
                success: false,
                errorMessage: error.message
              });
            }
          }
          
          // 更新同步会话状态
          await env.DB.prepare(`
            UPDATE sync_sessions SET records_processed = records_processed + ? WHERE id = ?
          `)
          .bind(records.length, sessionId)
          .run();
          
          return new Response(JSON.stringify({ 
            success: true,
            results 
          }), { 
            status: 200,
            headers: corsHeaders() 
          });
        }

        /**
         * 处理文件同步请求
         */
        async function handleSyncFiles(request, env) {
          // 解析multipart表单数据
          const formData = await request.formData();
          const sessionId = formData.get('sessionId');
          const recordId = formData.get('recordId');
          const fileType = formData.get('fileType');
          const file = formData.get('file');
          
          // 验证会话
          if (!await isValidSession(sessionId, env)) {
            return new Response(JSON.stringify({ 
              success: false, 
              message: '无效的同步会话' 
            }), { 
              status: 400,
              headers: corsHeaders() 
            });
          }
          
          // 验证参数
          if (!recordId || !fileType || !file) {
            return new Response(JSON.stringify({ 
              success: false, 
              message: '缺少必要的参数' 
            }), { 
              status: 400,
              headers: corsHeaders() 
            });
          }
          
          try {
            // 根据文件类型确定存储路径
            let path;
            if (fileType === 'original') {
              path = `photos/${recordId}.jpg`;
            } else if (fileType === 'thumbnail350') {
              path = `thumbnails/${recordId}_thumb350.jpg`;
            } else {
              throw new Error(`不支持的文件类型: ${fileType}`);
            }
            
            // 上传到R2
            await env.BUCKET.put(path, file);
            
            // 如果是原始文件，更新数据库
            if (fileType === 'original') {
              // 从同步记录中获取操作类型
              const syncRecord = await env.DB.prepare(`
                SELECT operation_type FROM sync_records 
                WHERE record_id = ? AND table_type = 'Photos' AND status = 'PENDING'
                ORDER BY timestamp DESC LIMIT 1
              `)
              .bind(recordId)
              .first();
              
              if (syncRecord) {
                const operationType = syncRecord.operation_type;
                
                if (operationType === 'ADD') {
                  // 插入新照片记录
                  await env.DB.prepare(`
                    INSERT OR REPLACE INTO photos (
                      id, path, thumbnail_path, sync_timestamp
                    ) VALUES (?, ?, ?, ?)
                  `)
                  .bind(
                    recordId, 
                    `photos/${recordId}.jpg`, 
                    `thumbnails/${recordId}_thumb350.jpg`,
                    new Date().toISOString()
                  )
                  .run();
                } else if (operationType === 'UPDATE') {
                  // 更新现有照片记录
                  await env.DB.prepare(`
                    UPDATE photos SET 
                      path = ?, 
                      thumbnail_path = ?, 
                      sync_timestamp = ?
                    WHERE id = ?
                  `)
                  .bind(
                    `photos/${recordId}.jpg`, 
                    `thumbnails/${recordId}_thumb350.jpg`,
                    new Date().toISOString(),
                    recordId
                  )
                  .run();
                }
                
                // 更新同步记录状态
                await env.DB.prepare(`
                  UPDATE sync_records SET status = 'COMPLETED' 
                  WHERE record_id = ? AND table_type = 'Photos' AND status = 'PENDING'
                `)
                .bind(recordId)
                .run();
              }
            }
            
            // 更新同步会话状态
            await env.DB.prepare(`
              UPDATE sync_sessions SET files_processed = files_processed + 1 WHERE id = ?
            `)
            .bind(sessionId)
            .run();
            
            return new Response(JSON.stringify({ 
              success: true,
              message: '文件上传成功'
            }), { 
              status: 200,
              headers: corsHeaders() 
            });
            
          } catch (error) {
            console.error(`文件上传错误: ${error.message}`);
            
            return new Response(JSON.stringify({ 
              success: false, 
              message: `文件上传失败: ${error.message}`
            }), { 
              status: 500,
              headers: corsHeaders() 
            });
          }
        }

        /**
         * 处理完成同步请求
         */
        async function handleFinalizeSync(request, env) {
          const data = await request.json();
          const { sessionId } = data;
          
          // 验证会话
          if (!await isValidSession(sessionId, env)) {
            return new Response(JSON.stringify({ 
              success: false, 
              message: '无效的同步会话' 
            }), { 
              status: 400,
              headers: corsHeaders() 
            });
          }
          
          // 获取会话状态
          const session = await env.DB.prepare(`
            SELECT * FROM sync_sessions WHERE id = ?
          `)
          .bind(sessionId)
          .first();
          
          if (!session) {
            return new Response(JSON.stringify({ 
              success: false, 
              message: '找不到同步会话' 
            }), { 
              status: 404,
              headers: corsHeaders() 
            });
          }
          
          // 检查未完成的记录
          const pendingRecords = await env.DB.prepare(`
            SELECT COUNT(*) as count FROM sync_records 
            WHERE session_id = ? AND status = 'PENDING'
          `)
          .bind(sessionId)
          .first();
          
          // 统计错误记录
          const errorRecords = await env.DB.prepare(`
            SELECT COUNT(*) as count FROM sync_records 
            WHERE session_id = ? AND status = 'ERROR'
          `)
          .bind(sessionId)
          .first();
          
          // 完成同步会话
          await env.DB.prepare(`
            UPDATE sync_sessions 
            SET status = ?, end_time = ?, error_count = ?
            WHERE id = ?
          `)
          .bind(
            pendingRecords.count > 0 ? 'INCOMPLETE' : 'COMPLETED',
            new Date().toISOString(),
            errorRecords.count,
            sessionId
          )
          .run();
          
          // 准备同步摘要
          const summary = {
            recordsProcessed: session.records_processed || 0,
            filesProcessed: session.files_processed || 0,
            errors: errorRecords.count || 0
          };
          
          return new Response(JSON.stringify({ 
            success: true,
            message: '同步会话已完成',
            summary
          }), { 
            status: 200,
            headers: corsHeaders() 
          });
        }

        /**
         * 验证API密钥
         */
        function isAuthorized(request, env) {
          const authHeader = request.headers.get('Authorization');
          const expectedValue = `Bearer ${env.API_KEY}`;
          
          if (!authHeader || authHeader !== expectedValue) {
            return false;
          }
          
          return true;
        }

        /**
         * 验证同步会话是否有效
         */
        async function isValidSession(sessionId, env) {
          if (!sessionId) return false;
          
          try {
            const session = await env.DB.prepare(`
              SELECT * FROM sync_sessions WHERE id = ? AND status != 'COMPLETED' AND status != 'ABORTED'
            `)
            .bind(sessionId)
            .first();
            
            return !!session;
          } catch (error) {
            console.error(`验证会话错误: ${error.message}`);
            return false;
          }
        }

        /**
         * CORS头部配置
         */
        function corsHeaders() {
          return {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
          };
        }

        /**
         * 处理CORS预检请求
         */
        function handleCORS(request) {
          return new Response(null, {
            status: 204,
            headers: corsHeaders()
          });
        }
        """
    }
    
    /// 生成数据库架构SQL
    static func generateDatabaseSchema() -> String {
        return """
        -- 同步会话表
        CREATE TABLE IF NOT EXISTS sync_sessions (
          id TEXT PRIMARY KEY,
          device_id TEXT NOT NULL,
          app_version TEXT NOT NULL,
          start_time TEXT NOT NULL,
          end_time TEXT,
          status TEXT NOT NULL, -- STARTED, COMPLETED, INCOMPLETE, ABORTED
          records_processed INTEGER DEFAULT 0,
          files_processed INTEGER DEFAULT 0,
          error_count INTEGER DEFAULT 0
        );

        -- 同步记录表
        CREATE TABLE IF NOT EXISTS sync_records (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          table_type TEXT NOT NULL,
          record_id TEXT NOT NULL,
          operation_type TEXT NOT NULL, -- ADD, UPDATE, DELETE
          timestamp TEXT NOT NULL,
          status TEXT NOT NULL, -- PENDING, COMPLETED, ERROR
          error_message TEXT,
          FOREIGN KEY (session_id) REFERENCES sync_sessions(id)
        );

        -- 照片元数据表
        CREATE TABLE IF NOT EXISTS photos (
          id TEXT PRIMARY KEY,
          path TEXT NOT NULL,
          thumbnail_path TEXT NOT NULL,
          sync_timestamp TEXT NOT NULL,
          metadata_json TEXT
        );

        -- 照片同步历史表
        CREATE TABLE IF NOT EXISTS sync_history (
          id TEXT PRIMARY KEY,
          timestamp TEXT NOT NULL,
          device_id TEXT NOT NULL,
          success BOOLEAN NOT NULL,
          sync_type TEXT NOT NULL,
          error_message TEXT,
          records_processed INTEGER,
          files_processed INTEGER
        );

        -- 创建索引以提高查询性能
        CREATE INDEX IF NOT EXISTS idx_sync_records_session_id ON sync_records (session_id);
        CREATE INDEX IF NOT EXISTS idx_sync_records_record_id ON sync_records (record_id);
        CREATE INDEX IF NOT EXISTS idx_sync_records_status ON sync_records (status);
        CREATE INDEX IF NOT EXISTS idx_sync_history_timestamp ON sync_history (timestamp);
        """
    }
    
    /// 生成wrangler.toml配置文件
    static func generateWranglerToml(config: CloudSyncConfiguration) -> String {
        return """
        name = "\(config.workerName)"
        main = "worker.js"
        compatibility_date = "2023-06-28"

        # R2存储桶配置
        [[r2_buckets]]
        binding = "BUCKET"
        bucket_name = "\(config.r2BucketName)" # 你的R2存储桶名称
        preview_bucket_name = "\(config.r2BucketName)-preview" # 开发环境使用

        # D1数据库配置
        [[d1_databases]]
        binding = "DB"
        database_name = "\(config.d1DatabaseName)" # 你的D1数据库名称
        database_id = "<在CloudFlare Dashboard创建D1数据库后获取ID>" # 需要手动更新

        # 环境变量
        [vars]
        API_KEY = "\(config.apiToken)" # API密钥

        # 开发环境配置
        [env.dev]
        vars = { API_KEY = "\(config.apiToken)-dev" }
        workers_dev = true
        """
    }
    
    /// 生成部署说明
    static func generateDeploymentInstructions(config: CloudSyncConfiguration) -> String {
        return """
        # TUI Portfolio 云同步 Worker 部署说明

        本文档提供了如何部署和配置TUI Portfolio云同步Worker的步骤。

        ## 准备工作

        1. 确保你已经有一个CloudFlare账户，并且登录到 [CloudFlare Dashboard](https://dash.cloudflare.com/)。
        2. 确保你的账户已启用Workers和R2服务。

        ## 步骤1: 设置R2存储桶

        1. 在CloudFlare Dashboard中，导航到 R2 > 创建存储桶
        2. 创建名为 `\(config.r2BucketName)` 的存储桶
        3. 记下存储桶名称，已填入wrangler.toml文件

        ## 步骤2: 创建D1数据库

        1. 在CloudFlare Dashboard中，导航到 Workers & Pages > D1 > 创建数据库
        2. 创建名为 `\(config.d1DatabaseName)` 的数据库
        3. 获取数据库ID，并更新wrangler.toml文件中的database_id字段
        4. 在本地保存schema.sql文件，然后运行:
           ```
           wrangler d1 execute \(config.d1DatabaseName) --file=schema.sql
           ```

        ## 步骤3: 安装和配置Wrangler CLI

        1. 确保安装了 Wrangler CLI:
           ```
           npm install -g wrangler
           ```

        2. 登录到CloudFlare:
           ```
           wrangler login
           ```

        ## 步骤4: 部署Worker

        1. 创建一个新文件夹，例如 `tui-sync-worker`:
           ```
           mkdir tui-sync-worker
           cd tui-sync-worker
           ```

        2. 创建以下文件:
           - `worker.js`：包含Worker代码
           - `wrangler.toml`：包含Worker配置
           - `schema.sql`：包含数据库架构

        3. 发布Worker:
           ```
           wrangler publish
           ```

        4. 成功部署后，你将获得一个 `\(config.workerName).workers.dev` 域名

        ## 参考

        - [CloudFlare Workers文档](https://developers.cloudflare.com/workers/)
        - [CloudFlare R2文档](https://developers.cloudflare.com/r2/)
        - [CloudFlare D1文档](https://developers.cloudflare.com/d1/)
        """
    }
}
