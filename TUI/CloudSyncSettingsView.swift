import SwiftUI

struct CloudSyncSettingsView: View {
    @ObservedObject private var controller = CloudSyncController.shared
    @State private var showSyncView = false
    @State private var showVerifyResult = false
    @State private var verifyResult: (success: Bool, message: String, count: Int) = (false, "", 0)
    @State private var isVerifying = false
    @State private var showClearCloudDataView = false
    
    @AppStorage("cloudSyncOnWifiOnly") private var syncOnWifiOnly = true
    @AppStorage("cloudSyncAutomatically") private var syncAutomatically = false
    @AppStorage("cloudSyncFrequency") private var syncFrequency = 3 // 0: 从不, 1: 每天, 2: 每周, 3: 每月
    
    var body: some View {
        List {
            Section(header: Text("云同步状态")) {
                HStack {
                    Text("上次同步")
                    Spacer()
                    Text(controller.lastSyncTimeString)
                        .foregroundColor(.gray)
                }
                
                Button(action: {
                    showSyncView = true
                }) {
                    HStack {
                        Text("开始同步")
                        Spacer()
                        if controller.isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                .disabled(controller.isSyncing)
                
                Button(action: {
                    verifyCloudSync()
                }) {
                    HStack {
                        Text("验证同步状态")
                        Spacer()
                        if isVerifying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "checkmark.shield")
                        }
                    }
                }
                .disabled(isVerifying || controller.isSyncing)
            }
            
            Section(header: Text("同步设置")) {
                Toggle("仅在WiFi网络下同步", isOn: $syncOnWifiOnly)
                
                Toggle("自动同步", isOn: $syncAutomatically)
                
                if syncAutomatically {
                    Picker("同步频率", selection: $syncFrequency) {
                        Text("从不").tag(0)
                        Text("每天").tag(1)
                        Text("每周").tag(2)
                        Text("每月").tag(3)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            
            Section(header: Text("云端存储")) {
                NavigationLink(destination: CloudContentBrowserView()) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("浏览云端照片")
                    }
                }
                
                Link(destination: URL(string: "https://tuiportfolio.com")!) {
                    HStack {
                        Image(systemName: "safari")
                        Text("访问网页版")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                }
            }
            
            Section(header: Text("高级")) {
                Button(action: {
                    showClearCloudDataView = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("清除云端数据")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("云同步")
        .sheet(isPresented: $showSyncView) {
            CloudSyncView()
        }
        // 添加sheet
        .sheet(isPresented: $showClearCloudDataView) {
            ClearCloudDataView()
        }
        .alert(isPresented: $showVerifyResult) {
            Alert(
                title: Text(verifyResult.success ? "验证成功" : "验证失败"),
                message: Text(verifyResult.message),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    private func verifyCloudSync() {
        isVerifying = true
        
        CloudSyncController.shared.verifySyncStatus { success, message, count in
            DispatchQueue.main.async {
                self.verifyResult = (success, message, count)
                self.showVerifyResult = true
                self.isVerifying = false
            }
        }
    }
}

// 云端内容浏览器(占位)
struct CloudContentBrowserView: View {
    @State private var photos: [CloudPhoto] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    struct CloudPhoto: Identifiable {
        let id: String
        let title: String
        let thumbnailUrl: URL
        let originalUrl: URL
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载云端照片...")
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                        .padding()
                    Text("加载失败")
                        .font(.headline)
                    Text(error)
                        .foregroundColor(.gray)
                    Button("重试") {
                        loadCloudPhotos()
                    }
                    .padding()
                }
            } else if photos.isEmpty {
                VStack {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                        .padding()
                    Text("没有找到云端照片")
                        .font(.headline)
                }
            } else {
                cloudPhotosGrid
            }
        }
        .navigationTitle("云端照片")
        .onAppear {
            loadCloudPhotos()
        }
    }
    
    var cloudPhotosGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 10) {
                ForEach(photos) { photo in
                    VStack {
                        AsyncImage(url: photo.thumbnailUrl) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                            } else {
                                ProgressView()
                            }
                        }
                        .frame(width: 150, height: 150)
                        .cornerRadius(8)
                        
                        Text(photo.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
            .padding()
        }
    }
    
    private func loadCloudPhotos() {
        isLoading = true
        errorMessage = nil
        
        // 这部分需要根据实际API实现
        // 暂时模拟API调用
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isLoading = false
            self.errorMessage = "功能开发中"
            self.photos = []
        }
    }
}
