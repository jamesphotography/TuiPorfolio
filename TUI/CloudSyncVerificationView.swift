import SwiftUI

struct CloudSyncVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isVerifying = false
    @State private var verificationResult: CloudSyncVerifier.VerificationResult?
    @State private var showingDetailedReport = false
    @State private var verificationSampleSize = 0
    @State private var showErrorMessage = false
    @State private var errorMessage = ""
    @State private var fullVerification = true
    
    private let sampleSizes = [10, 20, 50, 100, 0]
    
    var body: some View {
        NavigationView {
            Form {
                // 验证选项部分
                if !isVerifying && verificationResult == nil {
                    Section(header: Text("验证选项")) {
                        Toggle("完整验证", isOn: $fullVerification)
                            .onChange(of: fullVerification) { _, newValue in
                                if newValue {
                                    verificationSampleSize = 0 // 0表示全部照片
                                } else {
                                    verificationSampleSize = 20
                                }
                            }
                        
                        if !fullVerification {
                            Picker("验证照片数量", selection: $verificationSampleSize) {
                                ForEach(sampleSizes.filter { $0 > 0 }, id: \.self) { size in
                                    Text("\(size) 张照片").tag(size)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        Button(action: startVerification) {
                            Text("开始验证")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("TUIBLUE"))
                                .cornerRadius(8)
                        }
                        .disabled(isVerifying)
                    }
                }
                
                // 验证中状态显示
                if isVerifying {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .padding(.bottom, 8)
                                
                                Text("正在验证同步状态...")
                                    .font(.headline)
                                
                                Text("这可能需要几分钟时间，请耐心等待")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    }
                }
                
                // 验证结果显示
                if let result = verificationResult {
                    Section(header: Text("验证结果概览")) {
                        resultStatusView(result)
                        
                        HStack {
                            Text("本地照片总数")
                            Spacer()
                            Text("\(result.totalLocalPhotos)")
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Text("云端照片总数")
                            Spacer()
                            Text("\(result.totalCloudPhotos)")
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Text("已验证照片数")
                            Spacer()
                            Text("\(result.verifiedPhotos)")
                                .foregroundColor(.gray)
                        }
                        
                        if !result.missingPhotos.isEmpty {
                            HStack {
                                Text("云端缺失照片")
                                Spacer()
                                Text("\(result.missingPhotos.count)")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        if !result.metadataMismatch.isEmpty {
                            HStack {
                                Text("元数据不匹配")
                                Spacer()
                                Text("\(result.metadataMismatch.count)")
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        if !result.fileIntegrityFailed.isEmpty {
                            HStack {
                                Text("文件完整性错误")
                                Spacer()
                                Text("\(result.fileIntegrityFailed.count)")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Button(action: {
                            showingDetailedReport = true
                        }) {
                            Text("查看详细报告")
                                .foregroundColor(Color("TUIBLUE"))
                        }
                    }
                    
                    Section {
                        Button(action: {
                            self.verificationResult = nil
                        }) {
                            Text("重新验证")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("同步验证")
            .navigationBarItems(
                trailing: Button("关闭") {
                    dismiss()
                }
            )
            .alert(isPresented: $showErrorMessage) {
                Alert(
                    title: Text("验证错误"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
            .sheet(isPresented: $showingDetailedReport) {
                detailedReportView()
            }
        }
    }
    
    private func resultStatusView(_ result: CloudSyncVerifier.VerificationResult) -> some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(result.success ? .green : .orange)
                .padding(.trailing, 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.success ? "同步状态良好" : "同步存在问题")
                    .font(.headline)
                
                Text(result.message)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func detailedReportView() -> some View {
        NavigationView {
            ScrollView {
                if let report = verificationResult?.detailedReport {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("# 同步验证详细报告")
                            .font(.largeTitle)
                            .padding(.vertical, 8)
                        
                        markdownContent(report)
                    }
                    .padding()
                }
            }
            .navigationTitle("详细报告")
            .navigationBarItems(
                trailing: Button("关闭") {
                    showingDetailedReport = false
                }
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if let report = verificationResult?.detailedReport {
                            UIPasteboard.general.string = report
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
    
    private func markdownContent(_ content: String) -> some View {
        let sections = content.split(separator: "#").filter { !$0.isEmpty }
        
        return VStack(alignment: .leading, spacing: 20) {
            ForEach(0..<sections.count, id: \.self) { index in
                let section = String(sections[index])
                let lines = section.split(separator: "\n")
                
                if !lines.isEmpty {
                    let title = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let content = lines.dropFirst().joined(separator: "\n")
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("# \(title)")
                            .font(.title)
                            .foregroundColor(Color("TUIBLUE"))
                        
                        Text(content)
                            .font(.body)
                    }
                }
            }
        }
    }
    
    private func startVerification() {
        isVerifying = true
        verificationResult = nil
        
        // 开始验证
        CloudSyncVerifier.shared.verifySync(sampleSize: verificationSampleSize, forceRefresh: true) { result in
            DispatchQueue.main.async {
                self.isVerifying = false
                self.verificationResult = result
            }
        }
    }
}
