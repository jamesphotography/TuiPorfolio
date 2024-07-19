import SwiftUI

struct LensCountView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var lensCounts: [(String, Int, String)] = [] // (镜头型号, 照片数量, 最早时间)
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // HeadBarView
                HeadBarView(title: "Lens Count")
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
                        } else if lensCounts.isEmpty {
                            Text("No lens records found")
                                .padding()
                        } else {
                            Text("Found \(lensCounts.count) lens models")
                                .font(.caption2)
                                .padding(.leading, 16)
                                .padding(.top, 8)

                            ForEach(Array(lensCounts.enumerated()), id: \.element.0) { index, lensData in
                                let (model, count, earliestTime) = lensData
                                NavigationLink(destination: LensDetailView(lensModel: model)) {
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
        .onAppear(perform: loadLensCounts)
    }

    private func loadLensCounts() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .background).async {
            let lensInfo = SQLiteManager.shared.getLensInfo()
            
            DispatchQueue.main.async {
                self.lensCounts = lensInfo
                self.isLoading = false
                if lensInfo.isEmpty {
                    self.errorMessage = "No lens data found"
                }
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

struct LensCountView_Previews: PreviewProvider {
    static var previews: some View {
        LensCountView()
    }
}
