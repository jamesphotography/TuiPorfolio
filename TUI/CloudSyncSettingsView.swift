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
                        
                        // 帮助信息
                        helpSection
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
            .onAppear {
                loadConfiguration()
            }
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
                SecureField("输入CloudFlare API令牌", text: $apiToken)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                Text("在CloudFlare控制台中生成的API令牌")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            // 账户ID
            VStack(alignment: .leading) {
                Text("账户ID").font(.subheadline).foregroundColor(.secondary)
                TextField("输入CloudFlare账户ID", text: $accountId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                Text("在CloudFlare控制台右下角找到")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            // Worker名称
            VStack(alignment: .leading) {
                Text("Worker名称").font(.subheadline).foregroundColor(.secondary)
                TextField("输入Worker名称（不含.workers.dev）", text: $workerName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                Text("例如：my-tui-sync（不需要输入完整URL）")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            // R2存储桶
            VStack(alignment: .leading) {
                Text("R2存储桶名称").font(.subheadline).foregroundColor(.secondary)
                TextField("输入R2存储桶名称", text: $r2BucketName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                Text("用于存储照片的R2存储桶名称")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            // D1数据库
            VStack(alignment: .leading) {
                Text("D1数据库名称").font(.subheadline).foregroundColor(.secondary)
                TextField("输入D1数据库名称", text: $d1DatabaseName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                Text("用于存储照片元数据的D1数据库名称")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if CloudSyncConfiguration.shared.workerUrl != nil {
                Text("生成的Worker URL: \(CloudSyncConfiguration.shared.workerUrl!.absoluteString)")
                    .font(.caption)
                    .foregroundColor(.blue)
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
                    .background(Color("TUIBLUE"))
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
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    /// 帮助信息
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("设置帮助")
                .font(.headline)
                .padding(.bottom, 5)
            
            Text("如何获取CloudFlare信息:")
                .font(.subheadline)
            
            Link("• 如何创建API令牌", destination: URL(string: "https://developers.cloudflare.com/api/tokens/create/")!)
                .foregroundColor(.blue)
            
            Link("• 如何找到账户ID", destination: URL(string: "https://developers.cloudflare.com/fundamentals/get-started/basic-tasks/find-account-and-zone-ids/")!)
                .foregroundColor(.blue)
            
            Link("• 如何创建Worker", destination: URL(string: "https://developers.cloudflare.com/workers/get-started/guide/")!)
                .foregroundColor(.blue)
            
            Link("• 如何设置R2存储桶", destination: URL(string: "https://developers.cloudflare.com/r2/get-started/")!)
                .foregroundColor(.blue)
            
            Link("• 如何创建D1数据库", destination: URL(string: "https://developers.cloudflare.com/d1/get-started/")!)
                .foregroundColor(.blue)
            
            Button(action: {
                showSetupGuide()
            }) {
                Text("查看完整设置指南")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color("TUIBLUE"))
                    .cornerRadius(8)
                    .padding(.top, 5)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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
    
    /// 显示设置指南
    private func showSetupGuide() {
        // 这里可以导航到设置指南页面
        // 目前只显示一个提示
        showAlert(title: "设置指南", message: "完整设置指南功能即将上线。", isSuccess: true)
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

// MARK: - 预览
struct CloudSyncSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CloudSyncSettingsView()
    }
}
