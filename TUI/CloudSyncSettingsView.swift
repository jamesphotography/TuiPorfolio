import SwiftUI
import Foundation

struct CloudSyncSettingsView: View {
    // 环境属性
    @Environment(\.presentationMode) var presentationMode
    
    // 状态属性
    @State private var apiToken: String = CloudSyncConfiguration.shared.apiToken
    @State private var accountId: String = CloudSyncConfiguration.shared.accountId
    @State private var workerName: String = CloudSyncConfiguration.shared.workerName
    @State private var r2BucketName: String = CloudSyncConfiguration.shared.r2BucketName
    @State private var d1DatabaseName: String = CloudSyncConfiguration.shared.d1DatabaseName
    
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    @State private var showingDeleteConfirmation = false
    @State private var showWorkerCodeSheet = false
    @State private var showCopySuccessToast = false
    
    // Worker 示例代码
    private let workerCode = """
    // Worker 示例代码
    addEventListener('fetch', event => {
      event.respondWith(handleRequest(event.request))
    })
    
    async function handleRequest(request) {
      if (request.method === 'GET' && new URL(request.url).pathname === '/health') {
        return new Response(JSON.stringify({ status: 'ok' }), {
          headers: { 'Content-Type': 'application/json' }
        })
      }
      
      // 处理其他请求
      return new Response('TUI Portfolio Sync Worker is running!', {
        headers: { 'Content-Type': 'text/plain' }
      })
    }
    """
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 标题栏
                HeadBarView(title: "CloudFlare同步设置")
                    .padding(.top, geometry.safeAreaInsets.top)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 配置表单
                        configurationForm
                        
                        // 操作按钮
                        actionButtons
                        
                        // 配置状态
                        configurationStatus
                    }
                    .padding()
                    .background(Color("BGColor"))
                }
                
                // 底部导航栏
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
            .actionSheet(isPresented: $showingDeleteConfirmation) {
                ActionSheet(
                    title: Text("确认删除配置"),
                    message: Text("这将删除所有CloudFlare同步设置。此操作不可撤销。"),
                    buttons: [
                        .destructive(Text("删除配置")) {
                            CloudSyncConfiguration.shared.clearConfiguration()
                            loadConfiguration()
                            showAlert(title: "配置已删除", message: "所有CloudFlare同步设置已被清除。", isSuccess: true)
                        },
                        .cancel(Text("取消"))
                    ]
                )
            }
            .sheet(isPresented: $showWorkerCodeSheet) {
                WorkerCodeView(code: workerCode, onDismiss: {
                    showWorkerCodeSheet = false
                })
            }
            .overlay(
                showCopySuccessToast ? toastView : nil
            )
            .onAppear {
                loadConfiguration()
            }
            .navigationBarHidden(true) // 确保隐藏导航栏
        }
    }
    
    // MARK: - 子视图
    
    /// 配置表单
    private var configurationForm: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("CloudFlare配置信息")
                .font(.headline)
                .padding(.bottom, 5)
            
            // API令牌
            VStack(alignment: .leading) {
                Text("API令牌").font(.subheadline).foregroundColor(.secondary)
                Text("在CloudFlare控制台中生成的API令牌（位于右上角个人资料 -> API令牌 -> 创建令牌）")
                    .font(.caption2)
                    .foregroundColor(.gray)
                SecureField("输入CloudFlare API令牌", text: $apiToken)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            // 账户ID
            VStack(alignment: .leading) {
                Text("账户ID").font(.subheadline).foregroundColor(.secondary)
                Text("在CloudFlare控制台右下角找到的标识号码")
                    .font(.caption2)
                    .foregroundColor(.gray)
                TextField("输入CloudFlare账户ID", text: $accountId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            // Worker名称
            VStack(alignment: .leading) {
                Text("Worker名称").font(.subheadline).foregroundColor(.secondary)
                Text("例如：my-tui-sync（只需输入名称部分，不要包含域名）")
                    .font(.caption2)
                    .foregroundColor(.gray)
                TextField("输入Worker名称（不含.workers.dev）", text: $workerName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            // R2存储桶
            VStack(alignment: .leading) {
                Text("R2存储桶名称").font(.subheadline).foregroundColor(.secondary)
                Text("用于存储照片的R2存储桶名称（在R2页面创建）")
                    .font(.caption2)
                    .foregroundColor(.gray)
                TextField("输入R2存储桶名称", text: $r2BucketName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            // D1数据库
            VStack(alignment: .leading) {
                Text("D1数据库名称").font(.subheadline).foregroundColor(.secondary)
                Text("用于存储照片元数据的D1数据库名称（在D1页面创建）")
                    .font(.caption2)
                    .foregroundColor(.gray)
                TextField("输入D1数据库名称", text: $d1DatabaseName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            if CloudSyncConfiguration.shared.workerUrl != nil {
                HStack {
                    Text("生成的Worker URL:")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Link(CloudSyncConfiguration.shared.workerUrl!.absoluteString,
                         destination: CloudSyncConfiguration.shared.workerUrl!)
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button(action: {
                        UIPasteboard.general.string = CloudSyncConfiguration.shared.workerUrl!.absoluteString
                        withAnimation {
                            showCopySuccessToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showCopySuccessToast = false
                            }
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                }
                
                Button(action: {
                    showWorkerCodeSheet = true
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("查看/复制Worker代码")
                    }
                    .font(.caption)
                    .padding(8)
                    .foregroundColor(.white)
                    .background(Color.black)
                    .cornerRadius(5)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    /// 操作按钮
    private var actionButtons: some View {
        HStack(spacing: 15) {
            // 验证按钮
            Button(action: validateConfiguration) {
                Text("验证配置")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            // 保存按钮
            Button(action: saveConfiguration) {
                Text("保存配置")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            // 仅在已配置时显示删除按钮
            if CloudSyncConfiguration.shared.isConfigured {
                Button(action: { showingDeleteConfirmation = true }) {
                    Text("删除配置")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            // 在CloudSyncSettingsView的actionButtons视图中添加以下按钮

            NavigationLink(destination: CloudWorkerTemplateView()) {
                Text("查看Worker代码")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(!CloudSyncConfiguration.shared.isConfigured)
        }
    }
    
    /// 配置状态
    private var configurationStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("配置状态")
                .font(.headline)
                .padding(.bottom, 5)
            
            HStack {
                Text("同步功能:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(CloudSyncConfiguration.shared.isConfigured ? "已配置" : "未配置")
                    .fontWeight(.semibold)
                    .foregroundColor(CloudSyncConfiguration.shared.isConfigured ? .green : .orange)
            }
            
            if let lastSync = CloudSyncConfiguration.shared.lastSyncTime {
                HStack {
                    Text("上次同步:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(formatDate(lastSync))
                        .fontWeight(.semibold)
                }
            }
            
            Divider()
            
            Text("设置说明")
                .font(.headline)
                .padding(.top, 5)
            
            Text("完成以上配置后，您的照片数据将自动同步到CloudFlare。请确保您已经在CloudFlare控制台中创建了相应的Worker、R2存储桶和D1数据库。")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    /// 复制成功提示
    private var toastView: some View {
        VStack {
            Spacer()
            
            Text("已复制到剪贴板")
                .font(.caption)
                .padding(10)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.bottom, 50)
        }
    }
    
    // MARK: - 方法
    
    /// 加载当前配置
    private func loadConfiguration() {
        apiToken = CloudSyncConfiguration.shared.apiToken
        accountId = CloudSyncConfiguration.shared.accountId
        workerName = CloudSyncConfiguration.shared.workerName
        r2BucketName = CloudSyncConfiguration.shared.r2BucketName
        d1DatabaseName = CloudSyncConfiguration.shared.d1DatabaseName
    }
    
    /// 验证配置
    private func validateConfiguration() {
        // 先应用当前输入的值
        _ = CloudSyncConfiguration.shared.saveConfiguration(
            apiToken: apiToken,
            accountId: accountId,
            workerName: workerName,
            r2BucketName: r2BucketName,
            d1DatabaseName: d1DatabaseName
        )
        
        // 验证配置
        let result = CloudSyncConfiguration.shared.validateConfiguration()
        
        if result.isValid {
            showAlert(title: "验证成功", message: "配置验证通过，您可以保存配置了。", isSuccess: true)
        } else {
            showAlert(title: "验证失败", message: result.errorMessage ?? "配置不完整或无效。", isSuccess: false)
        }
    }
    
    /// 保存配置
    private func saveConfiguration() {
        let success = CloudSyncConfiguration.shared.saveConfiguration(
            apiToken: apiToken,
            accountId: accountId,
            workerName: workerName,
            r2BucketName: r2BucketName,
            d1DatabaseName: d1DatabaseName
        )
        
        if success {
            showAlert(title: "保存成功", message: "CloudFlare同步配置已保存。", isSuccess: true)
        } else {
            showAlert(title: "保存失败", message: "请确保填写了所有必填字段。", isSuccess: false)
        }
    }
    
    /// 显示提示
    private func showAlert(title: String, message: String, isSuccess: Bool) {
        self.alertTitle = title
        self.alertMessage = message
        self.isSuccess = isSuccess
        self.showingAlert = true
    }
    
    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Worker代码视图
struct WorkerCodeView: View {
    let code: String
    let onDismiss: () -> Void
    @State private var showCopiedToast = false
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    VStack(alignment: .leading) {
                        Text("Worker示例代码")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        Text("请在CloudFlare Workers中创建一个新的Worker，并粘贴以下代码。")
                            .font(.subheadline)
                            .padding(.bottom, 10)
                        
                        Text(code)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .padding()
                }
                
                Button(action: {
                    UIPasteboard.general.string = code
                    withAnimation {
                        showCopiedToast = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showCopiedToast = false
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("复制代码")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationBarTitle("Worker代码", displayMode: .inline)
            .navigationBarItems(trailing: Button("关闭") {
                onDismiss()
            })
            .overlay(
                showCopiedToast ? VStack {
                    Spacer()
                    Text("代码已复制到剪贴板")
                        .font(.caption)
                        .padding(10)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.bottom, 50)
                } : nil
            )
        }
    }
}

// MARK: - 预览
struct CloudSyncSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CloudSyncSettingsView()
    }
}
