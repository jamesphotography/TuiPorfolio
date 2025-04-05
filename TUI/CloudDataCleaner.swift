import Foundation
import SwiftUI

class CloudDataCleaner {
    static let shared = CloudDataCleaner()
    
    private let baseURL = "https://james.james-727.workers.dev/api"
    private let clearToken = "tui-clear-all-data" // 与Worker中一致的简单令牌
    
    private init() {}
    
    func clearAllCloudData(completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(baseURL)/clear?token=\(clearToken)") else {
            completion(false, "无效的API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        print("CloudCleaner: 发送清空请求...")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("CloudCleaner: 网络错误: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false, "网络错误: \(error.localizedDescription)")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("CloudCleaner: 无效的HTTP响应")
                DispatchQueue.main.async {
                    completion(false, "无效的HTTP响应")
                }
                return
            }
            
            if httpResponse.statusCode == 200 {
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("CloudCleaner: 服务器响应: \(responseString)")
                }
                
                DispatchQueue.main.async {
                    completion(true, "云端数据已清空")
                }
            } else {
                var message = "服务器错误: \(httpResponse.statusCode)"
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    message += " - \(responseString)"
                }
                
                print("CloudCleaner: \(message)")
                DispatchQueue.main.async {
                    completion(false, message)
                }
            }
        }
        
        task.resume()
    }
}

// 清空云数据的视图
struct ClearCloudDataView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isClearing = false
    @State private var showingAlert = false
    @State private var showingConfirmation = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("警告：此操作将清除云端所有数据")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("这是一个用于测试的临时功能。执行此操作将删除云端所有照片和元数据。此操作不可撤销，请谨慎使用。")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                showingConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("清空云端数据")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
                .cornerRadius(10)
            }
            .disabled(isClearing)
            
            if isClearing {
                ProgressView("正在清空云端数据...")
                    .padding()
            }
            
            Spacer()
            
            Button("返回") {
                dismiss()
            }
            .padding()
        }
        .padding()
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("确定")) {
                    if alertTitle.contains("成功") {
                        dismiss()
                    }
                }
            )
        }
        .confirmationDialog(
            "确定要清空云端数据吗？",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("是的，清空所有数据", role: .destructive) {
                clearCloudData()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("此操作将删除所有云端照片和数据，不可恢复！")
        }
    }
    
    private func clearCloudData() {
        isClearing = true
        
        CloudDataCleaner.shared.clearAllCloudData { success, message in
            isClearing = false
            
            alertTitle = success ? "清空成功" : "清空失败"
            alertMessage = message
            showingAlert = true
        }
    }
}
