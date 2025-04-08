/**
 * 渲染同步API文档页面
 * @returns {string} HTML字符串
 */
export function renderSyncApiDocsPage() {
    return `<!DOCTYPE html>
  <html>
  <head>
    <title>TUI Portfolio 同步API文档</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
      h1 { color: #333; }
      .endpoint { background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 15px; }
      .method { display: inline-block; padding: 3px 6px; border-radius: 3px; font-size: 12px; font-weight: bold; margin-right: 5px; }
      .method.post { background: #4CAF50; color: white; }
      .method.get { background: #2196F3; color: white; }
      code { background: #eee; padding: 2px 4px; border-radius: 3px; font-family: monospace; }
      pre { background: #f9f9f9; padding: 10px; border-radius: 5px; overflow-x: auto; }
      .back-link { margin-top: 30px; }
      .back-link a { color: #0066cc; }
      .auth-info { background: #ffe8d6; padding: 10px; border-left: 4px solid #ff7d00; margin-bottom: 20px; }
    </style>
  </head>
  <body>
    <h1>TUI Portfolio 同步API文档</h1>
    
    <div class="auth-info">
      <p><strong>身份验证</strong>：所有同步API都需要在请求头中包含<code>X-API-Key</code>来验证身份。</p>
    </div>
    
    <h2>初始化与增量同步</h2>
    
    <div class="endpoint">
      <h3><span class="method post">POST</span> /api/sync/initialize</h3>
      <p>初始化一个新的同步会话，用于首次同步或完整同步。</p>
      <p><strong>请求体</strong>:</p>
      <pre>{
    "deviceId": "设备唯一标识符",
    "userName": "用户名"
  }</pre>
      <p><strong>响应</strong>:</p>
      <pre>{
    "success": true,
    "syncId": "同步会话ID",
    "timestamp": "同步开始时间",
    "message": "Sync initialization successful"
  }</pre>
    </div>
    
    <div class="endpoint">
      <h3><span class="method post">POST</span> /api/sync/incremental</h3>
      <p>初始化一个增量同步会话，只同步上次同步后的变更。</p>
      <p><strong>请求体</strong>:</p>
      <pre>{
    "deviceId": "设备唯一标识符",
    "lastSyncTime": "上次同步时间（ISO8601格式）"
  }</pre>
      <p><strong>响应</strong>:</p>
      <pre>{
    "success": true,
    "syncId": "同步会话ID",
    "timestamp": "同步开始时间",
    "changes": [
      // 自上次同步以来的变更
    ],
    "message": "Incremental sync successful"
  }</pre>
    </div>
    
    <h2>数据同步</h2>
    
    <div class="endpoint">
      <h3><span class="method post">POST</span> /api/sync/database</h3>
      <p>同步照片元数据到服务器。</p>
      <p><strong>请求体</strong>:</p>
      <pre>{
    "syncId": "同步会话ID",
    "photos": [
      {
        // 照片元数据对象
        "Id": "照片ID",
        "Title": "标题",
        // ...其他照片属性
      }
    ],
    "isIncremental": true/false
  }</pre>
      <p><strong>响应</strong>:</p>
      <pre>{
    "success": true,
    "processed": 10,
    "added": 5,
    "updated": 5,
    "errors": [
      // 如果有错误
    ],
    "message": "Database sync successful"
  }</pre>
    </div>
    
    <div class="endpoint">
      <h3><span class="method post">POST</span> /api/sync/file</h3>
      <p>上传照片文件。使用multipart/form-data格式。</p>
      <p><strong>表单字段</strong>:</p>
      <ul>
        <li><code>syncId</code>: 同步会话ID</li>
        <li><code>filePath</code>: 文件路径</li>
        <li><code>file</code>: 文件内容</li>
      </ul>
      <p><strong>响应</strong>:</p>
      <pre>{
    "success": true,
    "filePath": "文件路径",
    "message": "File uploaded successfully"
  }</pre>
    </div>
    
    <h2>同步状态与验证</h2>
    
    <div class="endpoint">
      <h3><span class="method get">GET</span> /api/sync/status</h3>
      <p>获取同步状态。</p>
      <p><strong>查询参数</strong>:</p>
      <ul>
        <li><code>syncId</code>: 同步会话ID</li>
        <li>或 <code>deviceId</code>: 设备ID（获取最近的同步状态）</li>
      </ul>
      <p><strong>响应</strong>:</p>
      <pre>{
    "success": true,
    "status": {
      "session": {
        // 同步会话信息
      },
      "operations": [
        // 同步操作记录
      ]
    }
  }</pre>
    </div>
    
    <div class="endpoint">
      <h3><span class="method post">POST</span> /api/sync/verify</h3>
      <p>验证同步完成状态。</p>
      <p><strong>请求体</strong>:</p>
      <pre>{
    "syncId": "同步会话ID",
    "photoIds": [
      // 照片ID列表
    ]
  }</pre>
      <p><strong>响应</strong>:</p>
      <pre>{
    "success": true,
    "results": [
      {
        "id": "照片ID",
        "exists": true/false,
        "fileExists": true/false
      }
    ],
    "summary": {
      "total": 10,
      "found": 10,
      "missing": 0
    }
  }</pre>
    </div>
    
    <div class="back-link">
      <a href="/api">返回API文档</a>
    </div>
  </body>
  </html>`;
  }