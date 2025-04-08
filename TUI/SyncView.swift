import SwiftUI

struct SyncView: View {
    @State private var syncStatus: PhotoSyncStatus = PhotoSyncStatus(lastSyncTime: nil, isSyncing: false, pendingChanges: 0, syncError: nil)
    @State private var isSyncing: Bool = false
    @State private var syncProgress: Float = 0.0
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    @State private var showConfirmation: Bool = false
    @State private var forceFullSync: Bool = false
    @State private var syncHistory: [SyncHistoryItem] = []
    @State private var refreshTrigger: Bool = false
    @State private var healthCheckResult: String = "未检查"
    @State private var isCheckingHealth: Bool = false
    @State private var workerStatusColor: Color = .gray
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 头部导航栏
                HeadBarView(title: "云同步")
                    .padding(.top, geometry.safeAreaInsets.top)
                
                // 主内容区域
                ScrollView {
                    VStack(spacing: 20) {
                        // 连接状态检查
                        connectionStatusSection
                        
                        // 同步状态卡片
                        syncStatusCard
                        
                        // 同步控制按钮
                        syncControlSection
                        
                        // 同步历史记录
                        syncHistorySection
                        
                        // 调试信息
                        debugInfoSection
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
            .onAppear {
                loadSyncStatus()
                loadSyncHistory()
                checkWorkerHealth()
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("同步错误"),
                    message: Text(errorMessage ?? "未知错误"),
                    dismissButton: .default(Text("确定"))
                )
            }
            .actionSheet(isPresented: $showConfirmation) {
                ActionSheet(
                    title: Text("开始同步"),
                    message: Text("请选择同步类型"),
                    buttons: [
                        .default(Text("增量同步 (仅同步更改)")) {
                            startSync(forceFullSync: false)
                        },
                        .default(Text("完整同步 (同步所有数据)")) {
                            startSync(forceFullSync: true)
                        },
                        .cancel()
                    ]
                )
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
    
    // 连接状态检查部分
    private var connectionStatusSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Worker连接状态")
                    .font(.headline)
                
                Spacer()
                
                Button(action: checkWorkerHealth) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                        .rotationEffect(isCheckingHealth ? .degrees(360) : .zero)
                        .animation(isCheckingHealth ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isCheckingHealth)
                }
            }
            
            HStack {
                Circle()
                    .fill(workerStatusColor)
                    .frame(width: 12, height: 12)
                
                Text(healthCheckResult)
                    .font(.subheadline)
                
                Spacer()
                
                if isCheckingHealth {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if CloudSyncConfiguration.shared.workerUrl != nil {
                HStack {
                    Text("Worker URL:")
                        .font(.caption)
                    Text(CloudSyncConfiguration.shared.workerUrl?.absoluteString ?? "未设置")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            NavigationLink(destination: CloudSyncDebugView()) {
                Text("进行连接问题诊断")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // 同步状态卡片
    private var syncStatusCard: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: isSyncing ? "arrow.clockwise.circle" : "checkmark.circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSyncing ? .blue : .green)
                    .rotationEffect(isSyncing ? .degrees(360 * Double(syncProgress)) : .zero)
                    .animation(isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSyncing)
                
                Text(isSyncing ? "正在同步..." : "云同步状态")
                    .font(.headline)
                
                Spacer()
                
                if isSyncing {
                    Button(action: cancelSync) {
                        Text("取消")
                            .foregroundColor(.red)
                    }
                }
            }
            
            if isSyncing {
                ProgressView(value: CGFloat(syncProgress)) {
                    Text("\(Int(syncProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .progressViewStyle(LinearProgressViewStyle())
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("上次同步:")
                        .foregroundColor(.secondary)
                    Spacer()
                    if let lastSyncTime = syncStatus.lastSyncTime {
                        Text(formattedDate(lastSyncTime))
                            .foregroundColor(.primary)
                    } else {
                        Text("从未同步")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                
                HStack {
                    Text("待同步项:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(syncStatus.pendingChanges)")
                        .foregroundColor(syncStatus.pendingChanges > 0 ? .orange : .green)
                }
                
                if let error = syncStatus.syncError {
                    HStack {
                        Text("同步错误:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(error)
                            .foregroundColor(.red)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            
            if !CloudSyncConfiguration.shared.isConfigured {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("云同步未配置")
                        .foregroundColor(.orange)
                    Spacer()
                    NavigationLink(destination: CloudSyncSettingsView()) {
                        Text("设置")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // 同步控制区域
    private var syncControlSection: some View {
        VStack(spacing: 15) {
            Button(action: { showConfirmation = true }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 20))
                    Text("开始同步")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(CloudSyncConfiguration.shared.isConfigured ? Color("TUIBLUE") : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!CloudSyncConfiguration.shared.isConfigured || isSyncing || workerStatusColor == .red)
            
            HStack {
                Button(action: loadSyncStatus) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("刷新状态")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                
                NavigationLink(destination: CloudSyncSettingsView()) {
                    HStack {
                        Image(systemName: "gear")
                        Text("同步设置")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // 同步历史记录
    private var syncHistorySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("同步历史")
                    .font(.headline)
                Spacer()
                Button(action: loadSyncHistory) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
            }
            
            if syncHistory.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无同步历史")
                        .foregroundColor(.secondary)
                        .italic()
                    Spacer()
                }
                .padding()
            } else {
                ForEach(syncHistory) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: item.success ? "checkmark.circle" : "xmark.circle")
                                .foregroundColor(item.success ? .green : .red)
                            
                            Text(formattedDate(item.timestamp))
                            
                            Spacer()
                            
                            Text(item.syncType)
                                .font(.caption)
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                )
                        }
                        
                        if let error = item.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.leading, 26)
                        }
                        
                        if item.recordsProcessed > 0 || item.filesProcessed > 0 {
                            HStack {
                                Text("记录: \(item.recordsProcessed)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("文件: \(item.filesProcessed)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 26)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    if syncHistory.last?.id != item.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // 调试信息区域
    private var debugInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("调试信息")
                    .font(.headline)
                Spacer()
                
                // 添加导航链接到CloudSyncDebugView
                NavigationLink(destination: CloudSyncDebugView()) {
                    HStack {
                        Image(systemName: "network")
                        Text("连接测试")
                    }
                    .font(.caption)
                    .padding(6)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                    .foregroundColor(.blue)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Worker名称")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(CloudSyncConfiguration.shared.workerName.isEmpty ? "未设置" : CloudSyncConfiguration.shared.workerName)
                            .font(.caption)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("账户ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(CloudSyncConfiguration.shared.accountId.isEmpty ? "未设置" : CloudSyncConfiguration.shared.accountId.prefix(8) + "...")
                            .font(.caption)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Token")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(CloudSyncConfiguration.shared.apiToken.isEmpty ? "未设置" : "已设置 (\(CloudSyncConfiguration.shared.apiToken.count) 字符)")
                            .font(.caption)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("R2存储桶")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(CloudSyncConfiguration.shared.r2BucketName.isEmpty ? "未设置" : CloudSyncConfiguration.shared.r2BucketName)
                            .font(.caption)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("D1数据库")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(CloudSyncConfiguration.shared.d1DatabaseName.isEmpty ? "未设置" : CloudSyncConfiguration.shared.d1DatabaseName)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 4)
            }

            HStack {
                Button(action: {
                    // 复制详细调试信息到剪贴板
                    let debugInfo = """
                    === TUI CloudSync 调试信息 ===
                    时间: \(formattedDate(Date()))
                    
                    配置信息:
                    - Worker名称: \(CloudSyncConfiguration.shared.workerName)
                    - Worker URL: \(CloudSyncConfiguration.shared.workerUrl?.absoluteString ?? "未设置")
                    - 账户ID: \(CloudSyncConfiguration.shared.accountId)
                    - API Token: \(CloudSyncConfiguration.shared.apiToken.isEmpty ? "未设置" : "已设置 (\(CloudSyncConfiguration.shared.apiToken.count) 字符)")
                    - R2存储桶: \(CloudSyncConfiguration.shared.r2BucketName)
                    - D1数据库: \(CloudSyncConfiguration.shared.d1DatabaseName)
                    - 配置状态: \(CloudSyncConfiguration.shared.isConfigured ? "已配置" : "未配置")
                    - 上次同步: \(CloudSyncConfiguration.shared.lastSyncTime != nil ? formattedDate(CloudSyncConfiguration.shared.lastSyncTime!) : "未同步")
                    
                    同步状态:
                    - 健康检查: \(healthCheckResult)
                    - 待同步项: \(syncStatus.pendingChanges)
                    - 上次同步: \(syncStatus.lastSyncTime != nil ? formattedDate(syncStatus.lastSyncTime!) : "未同步")
                    - 同步错误: \(syncStatus.syncError ?? "无")
                    
                    系统信息:
                    - 设备型号: \(UIDevice.current.model)
                    - 系统版本: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
                    - 应用版本: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知")
                    """
                    
                    UIPasteboard.general.string = debugInfo
                    errorMessage = "调试信息已复制到剪贴板"
                    showErrorAlert = true
                }) {
                    Text("复制详细调试信息")
                        .font(.caption)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                
                // 添加简单的调试按钮
                Button(action: {
                    CloudSyncManager.shared.logDebugInfo()
                    errorMessage = "调试信息已输出到控制台"
                    showErrorAlert = true
                }) {
                    HStack {
                        Image(systemName: "terminal")
                        Text("控制台调试")
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 辅助方法
    // 检查Worker健康状态
    private func checkWorkerHealth() {
        guard CloudSyncConfiguration.shared.isConfigured,
              let workerUrl = CloudSyncConfiguration.shared.workerUrl else {
            healthCheckResult = "Worker未配置"
            workerStatusColor = .gray
            return
        }
        
        isCheckingHealth = true
        healthCheckResult = "正在检查..."
        
        Task {
            let (success, errorMsg) = await CloudSyncManager.shared.performHealthCheck()
            
            await MainActor.run {
                isCheckingHealth = false
                
                if success {
                    healthCheckResult = "Worker在线，连接正常"
                    workerStatusColor = .green
                } else {
                    healthCheckResult = "连接失败: \(errorMsg ?? "未知错误")"
                    workerStatusColor = .red
                }
            }
        }
    }
    
    // 加载同步状态
    private func loadSyncStatus() {
        isSyncing = CloudSyncManager.shared.isSyncing
        syncProgress = CloudSyncManager.shared.syncProgress
        
        if !isSyncing {
            // 只有在没有同步时才从数据库加载状态
            syncStatus = SQLiteManager.shared.getSyncStatus()
        }
        
        // 检查是否配置了云同步
        if !CloudSyncConfiguration.shared.isConfigured {
            syncStatus.syncError = "云同步未配置，请前往设置"
        }
    }
    
    // 加载同步历史
    private func loadSyncHistory() {
        // 假设我们有一个存储同步历史的表
        // 这里只是示例，实际实现需要添加数据库表和查询
        // TODO: 从数据库加载真实的同步历史
        
        // 示例数据
        syncHistory = [
            SyncHistoryItem(id: "1", timestamp: Date().addingTimeInterval(-86400), success: true, syncType: "增量同步", errorMessage: nil, recordsProcessed: 15, filesProcessed: 5),
            SyncHistoryItem(id: "2", timestamp: Date().addingTimeInterval(-172800), success: false, syncType: "完整同步", errorMessage: "网络连接超时", recordsProcessed: 0, filesProcessed: 0)
        ]
    }
    
    // 开始同步
    private func startSync(forceFullSync: Bool) {
        guard CloudSyncConfiguration.shared.isConfigured else {
            errorMessage = "云同步未配置，请前往设置"
            showErrorAlert = true
            return
        }
        
        isSyncing = true
        syncProgress = 0.0
        
        // 设置进度更新回调
        CloudSyncManager.shared.progressHandler = { progress in
            self.syncProgress = progress
        }
        
        // 开始同步
        CloudSyncManager.shared.startSync(forceFullSync: forceFullSync) { success, error in
            self.isSyncing = false
            
            if !success, let syncError = error {
                self.errorMessage = syncError.localizedDescription
                self.showErrorAlert = true
            }
            
            // 重新加载同步状态和历史
            self.loadSyncStatus()
            self.loadSyncHistory()
            
            // 更新UI
            self.refreshTrigger.toggle()
        }
    }
    
    // 取消同步
    private func cancelSync() {
        CloudSyncManager.shared.cancelSync()
        
        // 界面会通过进度回调更新
    }
    
    // 格式化日期
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// 同步历史项目
struct SyncHistoryItem: Identifiable {
    let id: String
    let timestamp: Date
    let success: Bool
    let syncType: String
    let errorMessage: String?
    let recordsProcessed: Int
    let filesProcessed: Int
}

struct SyncView_Previews: PreviewProvider {
    static var previews: some View {
        SyncView()
    }
}
