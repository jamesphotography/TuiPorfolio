import SwiftUI

struct CloudSyncDebugView: View {
    @State private var testResult: String = "未开始测试"
    @State private var isTesting: Bool = false
    @State private var logMessages: [String] = []
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                }
                
                Spacer()
                
                Text("CloudSync 连接测试")
                    .font(.headline)
                
                Spacer()
            }
            .padding()
            
            // 配置信息
            VStack(alignment: .leading, spacing: 10) {
                Text("当前配置:")
                    .font(.subheadline)
                    .bold()
                
                Text("Worker URL: \(CloudSyncConfiguration.shared.workerUrl?.absoluteString ?? "未配置")")
                    .font(.caption)
                
                Text("Worker名称: \(CloudSyncConfiguration.shared.workerName)")
                    .font(.caption)
                
                Text("API Token: \(CloudSyncConfiguration.shared.apiToken.isEmpty ? "未设置" : "已设置 (长度: \(CloudSyncConfiguration.shared.apiToken.count))")")
                    .font(.caption)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // 测试按钮
            Button(action: testConnection) {
                HStack {
                    Text(isTesting ? "测试中..." : "测试连接")
                    
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isTesting)
            
            // 测试结果
            Text(testResult)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(testResult.contains("成功") ? Color.green.opacity(0.1) :
                              testResult.contains("失败") ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                )
            
            // 日志输出
            VStack(alignment: .leading) {
                Text("调试日志:")
                    .font(.subheadline)
                    .bold()
                
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(logMessages.indices, id: \.self) { index in
                            Text(logMessages[index])
                                .font(.system(.caption, design: .monospaced))
                                .padding(.vertical, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .padding()
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
            }
            
            // 复制日志按钮
            Button(action: {
                let logText = logMessages.joined(separator: "\n")
                UIPasteboard.general.string = logText
            }) {
                Text("复制日志")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func testConnection() {
        guard let workerUrl = CloudSyncConfiguration.shared.workerUrl else {
            testResult = "测试失败: Worker URL未配置"
            return
        }
        
        isTesting = true
        logMessages.removeAll()
        testResult = "正在测试连接..."
        addLog("开始连接测试...")
        addLog("Worker URL: \(workerUrl.absoluteString)")
        
        // 测试普通URL连接
        testSimpleConnection { healthSuccess, healthError in
            // 测试健康检查端点
            testHealthEndpoint { success, error in
                DispatchQueue.main.async {
                    if success {
                        testResult = "连接测试成功: 可以访问健康检查端点"
                        addLog("健康检查测试成功!")
                    } else {
                        if healthSuccess {
                            testResult = "部分成功: 域名可以访问，但健康检查端点不可用"
                            addLog("健康检查端点不可用: \(error ?? "未知错误")")
                        } else {
                            testResult = "连接测试失败: \(error ?? "未知错误")"
                        }
                    }
                    isTesting = false
                }
            }
        }
    }
    
    private func testSimpleConnection(completion: @escaping (Bool, String?) -> Void) {
        guard let workerUrl = CloudSyncConfiguration.shared.workerUrl else {
            completion(false, "Worker URL未配置")
            return
        }
        
        addLog("测试域名连通性...")
        
        let session = URLSession.shared
        var request = URLRequest(url: workerUrl)
        request.timeoutInterval = 10
        
        let task = session.dataTask(with: request) { _, response, error in
            if let error = error {
                self.addLog("域名连接错误: \(error.localizedDescription)")
                
                if let nsError = error as NSError? {
                    self.addLog("错误代码: \(nsError.code), 域: \(nsError.domain)")
                    
                    if nsError.domain == NSURLErrorDomain {
                        switch nsError.code {
                        case NSURLErrorCannotFindHost:
                            self.addLog("错误类型: 找不到主机 (DNS解析失败)")
                        case NSURLErrorCannotConnectToHost:
                            self.addLog("错误类型: 无法连接到主机")
                        case NSURLErrorTimedOut:
                            self.addLog("错误类型: 连接超时")
                        case NSURLErrorNetworkConnectionLost:
                            self.addLog("错误类型: 网络连接丢失")
                        default:
                            self.addLog("错误类型: 其他URL错误")
                        }
                    }
                }
                
                completion(false, "域名连接失败: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.addLog("域名连接成功: HTTP \(httpResponse.statusCode)")
                completion(true, nil)
            } else {
                self.addLog("域名连接成功，但无HTTP响应")
                completion(true, "无HTTP响应")
            }
        }
        
        task.resume()
    }
    
    // 修改CloudSyncDebugView中的testHealthEndpoint方法
    private func testHealthEndpoint(completion: @escaping (Bool, String?) -> Void) {
        guard let workerUrl = CloudSyncConfiguration.shared.workerUrl else {
            completion(false, "Worker URL未配置")
            return
        }
        
        // 使用/api/hello替代/health作为健康检查端点
        let healthUrl = workerUrl.appendingPathComponent("api/hello")
        addLog("测试健康检查端点: \(healthUrl.absoluteString)")
        
        let session = URLSession.shared
        var request = URLRequest(url: healthUrl)
        request.timeoutInterval = 10
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                self.addLog("健康检查错误: \(error.localizedDescription)")
                completion(false, "健康检查失败: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.addLog("健康检查响应: HTTP \(httpResponse.statusCode)")
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    self.addLog("响应内容: \(responseString)")
                }
                
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    completion(true, nil)
                } else {
                    completion(false, "健康检查返回错误状态码: \(httpResponse.statusCode)")
                }
            } else {
                self.addLog("健康检查无HTTP响应")
                completion(false, "健康检查无HTTP响应")
            }
        }
        
        task.resume()
    }
    
    private func addLog(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.logMessages.append("[\(timestamp)] \(message)")
        }
    }
}

// 在CloudSyncManager中添加简单的调试输出扩展
extension CloudSyncManager {
    func logDebugInfo() {
        print("===== CloudSync 调试信息 =====")
        print("配置信息:")
        print("- 是否已配置: \(CloudSyncConfiguration.shared.isConfigured)")
        print("- Worker名称: \(CloudSyncConfiguration.shared.workerName)")
        print("- Worker URL: \(CloudSyncConfiguration.shared.workerUrl?.absoluteString ?? "未配置")")
        print("- API令牌: \(CloudSyncConfiguration.shared.apiToken.isEmpty ? "未配置" : "已配置 (长度: \(CloudSyncConfiguration.shared.apiToken.count))")")
        print("- R2存储桶: \(CloudSyncConfiguration.shared.r2BucketName)")
        print("- D1数据库: \(CloudSyncConfiguration.shared.d1DatabaseName)")
        print("- 上次同步: \(CloudSyncConfiguration.shared.lastSyncTime?.description ?? "从未同步")")
        print("同步状态:")
        print("- 正在同步: \(isSyncing)")
        print("- 同步进度: \(syncProgress)")
        print("- 上次错误: \(lastSyncError?.localizedDescription ?? "无")")
        print("============================")
    }
}

struct CloudSyncDebugView_Previews: PreviewProvider {
    static var previews: some View {
        CloudSyncDebugView()
    }
}
