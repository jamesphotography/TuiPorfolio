import SwiftUI

struct CameraCountView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var cameraCounts: [(String, Int, String)] = [] // (相机型号, 照片数量, 最早时间)
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // HeadBarView
                HeadBarView(title: "Camera Count")
                    .padding(.top, geometry.safeAreaInsets.top)

                // Main content area
                ScrollView {
                    VStack(spacing: 8) {
                        if isLoading {
                            ProgressView("Loading...")
                                .padding()
                        } else if let error = errorMessage {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                        } else if cameraCounts.isEmpty {
                            Text("No camera records found")
                                .padding()
                        } else {
                            Text("Found \(cameraCounts.count) camera models")
                                .font(.caption2)
                                .padding(.leading, 16)
                                .padding(.top, 8)

                            ForEach(Array(cameraCounts.enumerated()), id: \.element.0) { index, cameraData in
                                let (model, count, earliestTime) = cameraData
                                NavigationLink(destination: CameraDetailView(cameraModel: model)) {
                                    HStack {
                                        Text("No. \(index + 1)")
                                            .foregroundColor(.secondary)
                                            .frame(width: 50, alignment: .leading)
                                        VStack(alignment: .leading) {
                                            Text(model)
                                                .foregroundColor(.primary)
                                            Text("Last used: \(formatDate(earliestTime))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text("\(count)")
                                            .foregroundColor(.secondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .background(Color("BGColor"))

                // Bottom navigation bar
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadCameraCounts)
    }

    private func loadCameraCounts() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .background).async {
            let cameraInfo = SQLiteManager.shared.getCameraInfo()
            
            DispatchQueue.main.async {
                self.cameraCounts = cameraInfo
                self.isLoading = false
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if let date = dateFormatter.date(from: dateString) {
            dateFormatter.dateFormat = "MMM d, yyyy"
            return dateFormatter.string(from: date)
        }
        
        return dateString
    }
}
