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
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 头部导航栏
                HeadBarView(title: "云同步")
                    .padding(.top, geometry.safeAreaInsets.top)
                
                // 主内容区域
                ScrollView {
                    VStack(spacing: 20) {
                        // 同步状态卡片
                        syncStatusCard
                        
                        // 同步控制按钮
                        syncControlSection
                        
                        // 同步历史记录
                        syncHistorySection
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
            .disabled(!CloudSyncConfiguration.shared.isConfigured || isSyncing)
            
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
    
    // MARK: - 辅助方法
    
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
