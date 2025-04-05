import SwiftUI

struct CloudSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isSyncing = false
    @State private var syncProgress: Float = 0.0
    @State private var syncedPhotos: Int = 0
    @State private var totalPhotos: Int = 0
    @State private var statusMessage = "准备同步..."
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var failedItems: [String] = []
    @State private var showingFailedList = false
    @State private var photoLimit: Int? = nil
    @State private var isTestMode = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 顶部栏
            HStack {
                Button(action: {
                    if isSyncing {
                        showCancelConfirmation()
                    } else {
                        dismiss()
                    }
                }) {
                    Text("关闭")
                        .foregroundColor(isSyncing ? .gray : Color("TUIBLUE"))
                }
                .disabled(isSyncing)
                
                Spacer()
                
                Text("云同步")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    if !isSyncing {
                        startSync()
                    }
                }) {
                    Text("同步")
                        .foregroundColor(isSyncing ? .gray : Color("TUIBLUE"))
                }
                .disabled(isSyncing)
            }
            .padding()
            
            // 同步设置
            if !isSyncing {
                VStack(spacing: 10) {
                    Toggle("测试模式 (仅同步元数据，不上传文件)", isOn: $isTestMode)
                        .padding(.horizontal)
                    
                    HStack {
                        Text("照片数量限制:")
                        
                        Picker("照片数量", selection: $photoLimit) {
                            Text("全部照片").tag(nil as Int?)
                            Text("5 张").tag(5 as Int?)
                            Text("10 张").tag(10 as Int?)
                            Text("20 张").tag(20 as Int?)
                            Text("50 张").tag(50 as Int?)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            // 同步状态信息
            VStack(spacing: 16) {
                Image(systemName: isSyncing ? "cloud.fill" : "cloud")
                    .font(.system(size: 80))
                    .foregroundColor(Color("TUIBLUE"))
                    .padding()
                
                Text(statusMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if isSyncing {
                    ProgressView(value: syncProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 8)
                        .padding(.horizontal, 20)
                    
                    Text("\(syncedPhotos) / \(totalPhotos) 张照片")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                if !failedItems.isEmpty {
                    Button(action: {
                        showingFailedList = true
                    }) {
                        Text("查看 \(failedItems.count) 个失败项")
                            .foregroundColor(.red)
                            .padding(.vertical, 5)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            
            // 说明文本
            VStack(alignment: .leading, spacing: 8) {
                Text("说明：")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Text("• 云同步会将您的照片和元数据上传到云端服务器")
                    .font(.subheadline)
                
                Text("• 您可以在网页上查看您的照片集")
                    .font(.subheadline)
                
                Text("• 首次同步可能需要较长时间，请保持应用在前台")
                    .font(.subheadline)
                
                Text("• 同步过程中请勿关闭应用")
                    .font(.subheadline)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Spacer()
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("确定")) {
                    if alertTitle == "同步完成" || alertTitle == "同步失败" {
                        dismiss()
                    }
                }
            )
        }
        .sheet(isPresented: $showingFailedList) {
            failedItemsView
        }
        .onAppear {
            // 初始化云同步服务
            setupCloudSyncService()
        }
    }
    
    private var failedItemsView: some View {
        NavigationView {
            List {
                ForEach(failedItems, id: \.self) { item in
                    Text(item)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle("同步失败项")
            .navigationBarItems(trailing: Button("关闭") {
                showingFailedList = false
            })
        }
    }
    
    private func setupCloudSyncService() {
        CloudSyncService.shared.progressCallback = { progress, synced, total, status in
            self.syncProgress = progress
            self.syncedPhotos = synced
            self.totalPhotos = total
            
            // 更新状态消息
            self.statusMessage = status
        }
        
        CloudSyncService.shared.completionCallback = { success, message, failedList in
            self.isSyncing = false
            self.failedItems = failedList
            
            if success {
                self.alertTitle = "同步完成"
                self.statusMessage = "同步已完成"
            } else {
                self.alertTitle = "同步失败"
                self.statusMessage = "同步失败"
            }
            
            self.alertMessage = message
            if failedList.isEmpty {
                self.showingAlert = true
            } else {
                self.showingFailedList = true
            }
        }
    }
    
    private func startSync() {
        self.isSyncing = true
        self.statusMessage = "正在准备同步..."
        self.failedItems = []
        
        // 设置测试模式
        CloudSyncService.shared.testMode = isTestMode
        
        // 开始同步
        CloudSyncService.shared.syncAllPhotos(limit: photoLimit)
    }
    
    private func showCancelConfirmation() {
        self.alertTitle = "取消同步"
        self.alertMessage = "确定要取消当前同步任务吗？"
        
        self.showingAlert = true
    }
}

struct CloudSyncView_Previews: PreviewProvider {
    static var previews: some View {
        CloudSyncView()
    }
}
