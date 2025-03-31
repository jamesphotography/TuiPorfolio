import SwiftUI

struct BirdCountView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var birdCounts: [(String, Int, String, String)] = [] // (鸟类名称, 照片数量, 最早记录时间, 最新照片缩略图路径)
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var computationTime: TimeInterval = 0
    @State private var showingCopyAlert = false

    private var documentDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: NSLocalizedString("Bird Count", comment: ""))
                    .padding(.top, geometry.safeAreaInsets.top)

                ScrollView {
                    VStack(spacing: 8) {
                        if isLoading {
                            ProgressView("Loading...")
                                .padding()
                        } else if let error = errorMessage {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                        } else if birdCounts.isEmpty {
                            Text("No bird records found")
                                .padding()
                        } else {
                            HStack {
                                Text("Found \(birdCounts.count) bird species")
                                    .font(.headline)
                                    .padding(5)
                                Spacer()
                                Button(action: {
                                    shareText()
                                }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(Color("TUIBLUE"))
                                        .font(.subheadline)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            ForEach(Array(birdCounts.enumerated()), id: \.element.0) { index, birdData in
                                let (name, count, firstSeen, thumbnailPath) = birdData
                                NavigationLink(destination: ObjectNameView(objectName: name)) {
                                    HStack(spacing: 10) {
                                        Text("No. \(index + 1)")
                                            .foregroundColor(.secondary)
                                            .frame(width: 60, alignment: .leading)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                        
                                        AsyncImage(url: getFullImagePath(for: thumbnailPath)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                            case .success(let image):
                                                image.resizable()
                                            case .failure:
                                                Image(systemName: "exclamationmark.triangle")
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(5)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(name) (\(count)张)")
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Text("First seen: \(formatDate(firstSeen))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
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

                if !birdCounts.isEmpty {
                    Text("Computation Time: \(String(format: "%.3f", computationTime))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                }

                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadBirdCounts)
        .alert(isPresented: $showingCopyAlert) {
            Alert(
                title: Text("复制成功"),
                message: Text("鸟种列表已复制到剪贴板"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    private func generateShareText() -> String {
        var shareText = "我的观鸟记录：\n\n"
        for (index, birdData) in birdCounts.enumerated() {
            let (name, count, firstSeen, _) = birdData
            shareText += String(format: "No.%d %@ (%d张) %@\n",
                              index + 1,
                              name,
                              count,
                              formatDateForSharing(firstSeen))
        }
        return shareText
    }
    
    private func shareText() {
        let text = generateShareText()
        UIPasteboard.general.string = text
        showingCopyAlert = true
    }
    
    private func getFullImagePath(for relativePath: String) -> URL {
        return documentDirectory.appendingPathComponent(relativePath)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if let date = dateFormatter.date(from: dateString) {
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return dateFormatter.string(from: date)
        }
        return dateString
    }
    
    private func formatDateForSharing(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if let date = dateFormatter.date(from: dateString) {
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return dateFormatter.string(from: date)
        }
        return dateString
    }
    
    private func loadBirdCounts() {
        if let cachedCounts = BirdCountCache.shared.birdCounts, !BirdCountCache.shared.shouldUpdate() {
            self.birdCounts = cachedCounts
            return
        }
        
        isLoading = true
        errorMessage = nil

        let startTime = CFAbsoluteTimeGetCurrent()

        DispatchQueue.global(qos: .background).async {
            do {
                let allObjectNames = SQLiteManager.shared.getAllObjectNames()
                let birdList = try loadBirdList()
                let earliestTimes = SQLiteManager.shared.getEarliestPhotoTimeForBirds()
                let latestPhotoInfo = SQLiteManager.shared.getLatestPhotoInfoForBirds()
                
                let filteredBirdCounts = allObjectNames.filter { objectName, _ in
                    birdList.contains { birdNames in
                        birdNames.contains(objectName)
                    }
                }
                
                var birdCounts = filteredBirdCounts.compactMap { (objectName, count) -> (String, Int, String, String)? in
                    if let earliestTime = earliestTimes.first(where: { $0.0 == objectName })?.1,
                       let latestPhotoThumbnail = latestPhotoInfo.first(where: { $0.0 == objectName })?.1 {
                        return (objectName, count, earliestTime, latestPhotoThumbnail)
                    }
                    return nil
                }
                
                // 按首次拍摄时间排序
                birdCounts.sort { $0.2 < $1.2 }
                
                let endTime = CFAbsoluteTimeGetCurrent()
                let computationTime = endTime - startTime
                
                DispatchQueue.main.async {
                    self.birdCounts = birdCounts
                    BirdCountCache.shared.update(with: birdCounts)
                    self.isLoading = false
                    self.computationTime = computationTime
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func loadBirdList() throws -> [[String]] {
        guard let url = Bundle.main.url(forResource: "birdInfo", withExtension: "json") else {
            throw NSError(domain: "BirdCountView", code: 1, userInfo: [NSLocalizedDescriptionKey: "birdInfo.json file not found"])
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([[String]].self, from: data)
    }
}

struct BirdCountView_Previews: PreviewProvider {
    static var previews: some View {
        BirdCountView()
    }
}
