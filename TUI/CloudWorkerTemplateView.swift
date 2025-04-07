import SwiftUI

struct CloudWorkerTemplateView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var showCopySuccessAlert = false
    @State private var selectedTab = 0
    
    // 存储配置信息
    private let config = CloudSyncConfiguration.shared
    
    // 代码部分类型
    enum CodeSection: String, CaseIterable {
        case full = "完整代码"
        case htmlTemplates = "HTML模板"
        case apiEndpoints = "API端点"
        case fileHandling = "文件处理"
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 自定义导航栏
                HStack {
                    Button(action: {
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                            .padding()
                    }
                    
                    Spacer()
                    
                    Text("Worker代码模板")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        copyCodeToClipboard()
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(Color("TUIBLUE"))
                            .padding()
                    }
                }
                .background(Color.gray.opacity(0.1))
                
                // 分段控制器
                Picker("代码部分", selection: $selectedTab) {
                    ForEach(0..<CodeSection.allCases.count, id: \.self) { index in
                        Text(CodeSection.allCases[index].rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // 代码区域
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 部署说明
                        deploymentInstructions
                            .padding(.bottom, 10)
                        
                        // 代码显示
                        codeView
                            .padding([.horizontal, .bottom])
                    }
                    .padding()
                }
                .background(Color("BGColor"))
            }
            .alert(isPresented: $showCopySuccessAlert) {
                Alert(
                    title: Text("复制成功"),
                    message: Text("代码已复制到剪贴板"),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
    
    // 部署说明
    private var deploymentInstructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("部署说明")
                .font(.headline)
                .padding(.bottom, 5)
            
            Text("1. 登录Cloudflare控制台，创建一个新的Worker")
                .font(.subheadline)
            
            Text("2. 复制下方代码并粘贴到Worker编辑器中")
                .font(.subheadline)
            
            Text("3. 设置Worker绑定：")
                .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• 创建D1数据库绑定：变量名为'data'")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• 创建R2存储桶绑定：变量名为'images'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading)
            
            Text("4. 在Worker设置中，添加自定义域名（可选）")
                .font(.subheadline)
            
            Text("5. 保存并部署")
                .font(.subheadline)
            
            if let workerUrl = config.workerUrl {
                Text("部署后，您的Worker将可通过以下URL访问：")
                    .font(.caption)
                    .padding(.top, 5)
                
                Text(workerUrl.absoluteString)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 1)
    }
    
    // 代码视图
    private var codeView: some View {
        VStack(alignment: .leading) {
            // 代码内容
            ScrollView {
                Text(getCodeContent())
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // 复制按钮
            Button(action: {
                copyCodeToClipboard()
            }) {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("复制代码")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color("TUIBLUE"))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.top, 10)
        }
    }
    
    // 获取当前选择的代码内容
    private func getCodeContent() -> String {
        let section = CodeSection.allCases[selectedTab]
        
        switch section {
        case .full:
            return fullWorkerCode
        case .htmlTemplates:
            return htmlTemplatesCode
        case .apiEndpoints:
            return apiEndpointsCode
        case .fileHandling:
            return fileHandlingCode
        }
    }
    
    // 复制代码到剪贴板
    private func copyCodeToClipboard() {
        UIPasteboard.general.string = getCodeContent()
        showCopySuccessAlert = true
    }
    
    // 完整代码
    private var fullWorkerCode: String {
        return """
var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// templates/home.js
function renderHomePage(photos, page, totalPages) {
  photos = Array.isArray(photos) ? photos : [];
  let photosHtml = "";
  for (const photo of photos) {
    const thumbnailUrl = photo.ThumbnailPath350 ? `/api/files/${photo.ThumbnailPath350}` : "https://via.placeholder.com/350x350";
    const displayTitle = photo.ObjectName || photo.Title || "无标题";
    let locationInfo = [];
    if (photo.Locality) locationInfo.push(photo.Locality);
    if (photo.Area) locationInfo.push(photo.Area);
    if (photo.Country) locationInfo.push(photo.Country);
    const locationStr = locationInfo.length > 0 ? locationInfo.join(", ") : "";
    photosHtml += `
      <div class="photo-card">
        <a href="/photo/${photo.Id}">
          <div class="photo-square">
            <img src="${thumbnailUrl}" alt="${displayTitle}">
          </div>
          <div class="photo-info">
            <h3>${displayTitle}</h3>
            <p>${photo.DateTimeOriginal ? new Date(photo.DateTimeOriginal).toLocaleDateString() : "未知日期"}</p>
            ${locationStr ? `<p class="location">${locationStr}</p>` : ""}
          </div>
        </a>
      </div>
    `;
  }
  let paginationHtml = '<div class="pagination">';
  if (page > 1) {
    paginationHtml += `<a href="/?page=${page - 1}" class="page-link">&laquo; 上一页</a>`;
  }
  const startPage = Math.max(1, page - 2);
  const endPage = Math.min(totalPages, page + 2);
  for (let i = startPage; i <= endPage; i++) {
    paginationHtml += `<a href="/?page=${i}" class="page-link ${i === page ? "active" : ""}">${i}</a>`;
  }
  if (page < totalPages) {
    paginationHtml += `<a href="/?page=${page + 1}" class="page-link">下一页 &raquo;</a>`;
  }
  paginationHtml += "</div>";
  return `<!DOCTYPE html>
<html>
<head>
  <title>${config.userName}'s Portfolio</title>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { 
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
      max-width: 1200px; 
      margin: 0 auto; 
      padding: 20px;
      background-color: #f5f5f7;
    }
    h1 { 
      color: #333; 
      text-align: center;
      margin-bottom: 30px;
    }
    .photo-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
      gap: 20px;
      margin-bottom: 40px;
    }
    .photo-card {
      background: white;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
      transition: transform 0.3s ease;
    }
    .photo-card:hover {
      transform: translateY(-5px);
    }
    .photo-square {
      position: relative;
      width: 100%;
      padding-bottom: 100%; /* 创建1:1的方形比例 */
      overflow: hidden;
    }
    .photo-square img {
      position: absolute;
      width: 100%;
      height: 100%;
      object-fit: cover; /* 保持图片比例并填充容器 */
      top: 0;
      left: 0;
    }
    .photo-info {
      padding: 15px;
    }
    .photo-info h3 {
      margin: 0 0 8px 0;
      font-size: 16px;
    }
    .photo-info p {
      margin: 0;
      color: #666;
      font-size: 14px;
    }
    .location {
      margin-top: 5px !important;
      color: #0066cc !important;
    }
    .pagination {
      display: flex;
      justify-content: center;
      margin-top: 30px;
    }
    .page-link {
      display: inline-block;
      padding: 8px 12px;
      margin: 0 5px;
      background: white;
      border-radius: 4px;
      text-decoration: none;
      color: #333;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .page-link.active {
      background: #0066cc;
      color: white;
    }
    a {
      text-decoration: none;
      color: inherit;
    }
    .api-link {
      text-align: center;
      margin-top: 40px;
      padding-top: 20px;
      border-top: 1px solid #ddd;
    }
    .api-link a {
      color: #0066cc;
      text-decoration: underline;
    }
    .empty-state {
      text-align: center;
      padding: 50px 0;
      color: #666;
    }
  </style>
</head>
<body>
  <h1>${config.userName}'s Portfolio</h1>
  
  ${photos.length > 0 ? `<div class="photo-grid">${photosHtml}</div>
     ${paginationHtml}` : `<div class="empty-state">
       <h2>暂无照片</h2>
       <p>数据库中还没有照片，请先添加一些照片。</p>
     </div>`}
  
  <div class="api-link">
    <a href="/api">查看API文档</a>
  </div>
</body>
</html>`;
}
__name(renderHomePage, "renderHomePage");

// 路由设置
var routes = {
  // 首页路由
  "GET /": handleHome,
  // API文档页面
  "GET /api": handleApiDocs,
  // API端点
  "GET /api/hello": handleHelloWorld,
  "GET /api/photos": handleGetPhotos,
  "GET /api/photos/count": handleGetPhotoCount
};

var dynamicRoutes = [
  {
    pattern: /^\\/api\\/photos\\/([^\\/]+)$/,
    method: "GET",
    handler: async (request, env, matches) => {
      const id = matches[1];
      return await handleGetPhoto(request, env, id);
    }
  },
  // 照片详情页面路由
  {
    pattern: /^\\/photo\\/([^\\/]+)$/,
    method: "GET",
    handler: async (request, env, matches) => {
      const id = matches[1];
      return await handlePhotoDetail(request, env, id);
    }
  },
  // 文件访问路由
  {
    pattern: /^\\/api\\/files\\/(.+)$/,
    method: "GET",
    handler: async (request, env, matches) => {
      const filePath = matches[1];
      return await handleGetFile(request, env, filePath);
    }
  }
];

export default {
  async fetch(request, env, ctx) {
    try {
      if (request.method === "OPTIONS") {
        return handleOptions(request);
      }
      
      const url = new URL(request.url);
      const path = url.pathname;
      const routeKey = `${request.method} ${path}`;
      
      const handler = routes[routeKey];
      if (handler) {
        return await handler(request, env);
      }
      
      for (const route of dynamicRoutes) {
        if (request.method === route.method) {
          const matches = path.match(route.pattern);
          if (matches) {
            return await route.handler(request, env, matches);
          }
        }
      }
      
      return new Response("Not Found", {
        status: 404,
        headers: { "Access-Control-Allow-Origin": "*" }
      });
    } catch (error) {
      console.error("Server error:", error);
      return new Response("Server Error: " + error.message, {
        status: 500,
        headers: { "Access-Control-Allow-Origin": "*" }
      });
    }
  }
};

function handleOptions(request) {
  return new Response(null, {
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
      "Access-Control-Max-Age": "86400"
    }
  });
}
"""
    }
    
    // HTML模板代码
    private var htmlTemplatesCode: String {
        return """
// HTML模板 - 首页
function renderHomePage(photos, page, totalPages) {
  photos = Array.isArray(photos) ? photos : [];
  let photosHtml = "";
  
  for (const photo of photos) {
    const thumbnailUrl = photo.ThumbnailPath350 ? `/api/files/${photo.ThumbnailPath350}` : "https://via.placeholder.com/350x350";
    const displayTitle = photo.ObjectName || photo.Title || "无标题";
    
    let locationInfo = [];
    if (photo.Locality) locationInfo.push(photo.Locality);
    if (photo.Area) locationInfo.push(photo.Area);
    if (photo.Country) locationInfo.push(photo.Country);
    const locationStr = locationInfo.length > 0 ? locationInfo.join(", ") : "";
    
    photosHtml += `
      <div class="photo-card">
        <a href="/photo/${photo.Id}">
          <div class="photo-square">
            <img src="${thumbnailUrl}" alt="${displayTitle}">
          </div>
          <div class="photo-info">
            <h3>${displayTitle}</h3>
            <p>${photo.DateTimeOriginal ? new Date(photo.DateTimeOriginal).toLocaleDateString() : "未知日期"}</p>
            ${locationStr ? `<p class="location">${locationStr}</p>` : ""}
          </div>
        </a>
      </div>
    `;
  }
  
  // 分页导航
  let paginationHtml = '<div class="pagination">';
  if (page > 1) {
    paginationHtml += `<a href="/?page=${page - 1}" class="page-link">&laquo; 上一页</a>`;
  }
  
  const startPage = Math.max(1, page - 2);
  const endPage = Math.min(totalPages, page + 2);
  
  for (let i = startPage; i <= endPage; i++) {
    paginationHtml += `<a href="/?page=${i}" class="page-link ${i === page ? "active" : ""}">${i}</a>`;
  }
  
  if (page < totalPages) {
    paginationHtml += `<a href="/?page=${page + 1}" class="page-link">下一页 &raquo;</a>`;
  }
  paginationHtml += "</div>";
  
  // 完整HTML
  return `<!DOCTYPE html>
  <html>
    <head>
      <title>用户名's Portfolio</title>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        /* 这里是CSS样式 */
        body { 
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
          max-width: 1200px; 
          margin: 0 auto; 
          padding: 20px;
          background-color: #f5f5f7;
        }
        /* ...更多CSS... */
      </style>
    </head>
    <body>
      <h1>用户名's Portfolio</h1>
      
      ${photos.length > 0 ? `<div class="photo-grid">${photosHtml}</div>
         ${paginationHtml}` : `<div class="empty-state">
           <h2>暂无照片</h2>
           <p>数据库中还没有照片，请先添加一些照片。</p>
         </div>`}
      
      <div class="api-link">
        <a href="/api">查看API文档</a>
      </div>
    </body>
  </html>`;
}

// HTML模板 - 照片详情页
function renderPhotoPage(photo, prevId, nextId) {
  const originalUrl = photo.Path ? `/api/files/${photo.Path}` : null;
  const displayUrl = photo.ThumbnailPath1024 ? `/api/files/${photo.ThumbnailPath1024}` : photo.Path ? `/api/files/${photo.Path}` : "https://via.placeholder.com/800x600";
  const displayTitle = photo.ObjectName || photo.Title || "无标题";
  
  // 构建日期显示
  const dateStr = photo.DateTimeOriginal ? new Date(photo.DateTimeOriginal).toLocaleDateString("zh-CN", {
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  }) : "未知日期";
  
  // 构建位置信息
  let locationInfo = [];
  if (photo.Locality) locationInfo.push(photo.Locality);
  if (photo.Area) locationInfo.push(photo.Area);
  if (photo.Country) locationInfo.push(photo.Country);
  const locationStr = locationInfo.length > 0 ? locationInfo.join(", ") : "未知位置";
  
  // 曝光时间格式化
  let exposureTimeStr = "未知";
  if (photo.ExposureTime) {
    const exposureTime = parseFloat(photo.ExposureTime);
    if (exposureTime >= 1) {
      exposureTimeStr = `${exposureTime}秒`;
    } else {
      const denominator = Math.round(1 / exposureTime);
      exposureTimeStr = `1/${denominator}秒`;
    }
  }
  
  return `<!DOCTYPE html>
  <html>
    <!-- HTML头部和样式 -->
    <body>
      <!-- 照片详情内容 -->
    </body>
  </html>`;
}

// HTML模板 - 错误页面
function renderErrorPage(error) {
  return `<!DOCTYPE html>
<html>
<head>
  <title>错误 - 用户名's Portfolio</title>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { 
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
      max-width: 800px; 
      margin: 0 auto; 
      padding: 20px;
      text-align: center;
    }
    .error {
      margin-top: 50px;
      padding: 20px;
      background: #fff0f0;
      border-radius: 8px;
      border-left: 5px solid #ff3b30;
    }
    h1 { color: #ff3b30; }
  </style>
</head>
<body>
  <div class="error">
    <h1>出错了</h1>
    <p>加载照片时发生错误: ${error.message}</p>
    <p><a href="/">返回首页</a></p>
  </div>
</body>
</html>`;
}
"""
    }
    
    // API端点代码
    private var apiEndpointsCode: String {
        return """
// API处理函数 - 获取照片列表
async function handleGetPhotos(request, env) {
  try {
    const url = new URL(request.url);
    const limit = parseInt(url.searchParams.get("limit") || "50");
    const offset = parseInt(url.searchParams.get("offset") || "0");
    
    const stmt = env.data.prepare(
      `SELECT * FROM Photos ORDER BY DateTimeOriginal DESC LIMIT ? OFFSET ?`
    );
    const result = await stmt.bind(limit, offset).all();
    
    return jsonResponse(result.results);
  } catch (error) {
    console.error("Failed to get photos:", error);
    return jsonResponse({
      error: "Failed to get photos: " + error.message
    }, 500);
  }
}

// API处理函数 - 获取照片数量
async function handleGetPhotoCount(request, env) {
  try {
    const countStmt = env.data.prepare(`SELECT COUNT(*) as count FROM Photos`);
    const result = await countStmt.first();
    const count = result ? result.count : 0;
    
    return jsonResponse({ count });
  } catch (error) {
    console.error("Failed to count photos:", error);
    return jsonResponse({
      error: "Failed to count photos: " + error.message
    }, 500);
  }
}

// API处理函数 - 获取单张照片
async function handleGetPhoto(request, env, id) {
  try {
    const stmt = env.data.prepare(`SELECT * FROM Photos WHERE Id = ?`);
    const result = await stmt.bind(id).first();
    
    if (!result) {
      return jsonResponse({ error: "Photo not found" }, 404);
    }
    
    return jsonResponse(result);
  } catch (error) {
    console.error("Failed to get photo:", error);
    return jsonResponse({
      error: "Failed to get photo: " + error.message
    }, 500);
  }
}

// API处理函数 - Hello World
function handleHelloWorld(request, env) {
  const timestamp = new Date().toISOString();
  return jsonResponse({
    message: "Hello World from TUI Portfolio API!",
    timestamp,
    version: "1.0.0"
  });
}

// 辅助函数 - 生成JSON响应
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*"
    }
  });
}
"""
    }
    
    // 文件处理代码
    private var fileHandlingCode: String {
        return """
// 文件处理 - 从R2获取文件
async function handleGetFile(request, env, filePath) {
  try {
    // 从R2存储桶获取文件
    const object = await env.images.get(filePath);
    
    if (!object) {
      return new Response("File not found", { status: 404 });
    }
    
    // 根据文件扩展名确定Content-Type
    let contentType = "application/octet-stream";
    if (filePath.endsWith(".jpg") || filePath.endsWith(".jpeg")) {
      contentType = "image/jpeg";
    } else if (filePath.endsWith(".png")) {
      contentType = "image/png";
    } else if (filePath.endsWith(".gif")) {
      contentType = "image/gif";
    } else if (filePath.endsWith(".webp")) {
      contentType = "image/webp";
    }
    
    // 返回文件响应
    return new Response(object.body, {
      headers: {
        "Content-Type": contentType,
        "Content-Length": object.size,
        "Access-Control-Allow-Origin": "*",
        "Cache-Control": "public, max-age=31536000" // 缓存一年
      }
    });
  } catch (error) {
    console.error("Failed to get file:", error);
    return new Response("Failed to get file: " + error.message, { status: 500 });
  }
}

// 处理CORS预检请求
function handleOptions(request) {
  return new Response(null, {
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
      "Access-Control-Max-Age": "86400"
    }
  });
}

// Worker主体
export default {
  async fetch(request, env, ctx) {
    try {
      // 处理CORS预检请求
      if (request.method === "OPTIONS") {
        return handleOptions(request);
      }
      
      const url = new URL(request.url);
      const path = url.pathname;
      const routeKey = `${request.method} ${path}`;
      
      // 检查静态路由
      const handler = routes[routeKey];
      if (handler) {
        return await handler(request, env);
      }
      
      // 检查动态路由
      for (const route of dynamicRoutes) {
        if (request.method === route.method) {
          const matches = path.match(route.pattern);
          if (matches) {
            return await route.handler(request, env, matches);
          }
        }
      }
      
      // 未找到对应路由
      return new Response("Not Found", {
        status: 404,
        headers: { "Access-Control-Allow-Origin": "*" }
      });
    } catch (error) {
      console.error("Server error:", error);
      return new Response("Server Error: " + error.message, {
        status: 500,
        headers: { "Access-Control-Allow-Origin": "*" }
      });
    }
  }
};
"""
    }
}

struct CloudWorkerTemplateView_Previews: PreviewProvider {
    static var previews: some View {
        CloudWorkerTemplateView()
    }
}
