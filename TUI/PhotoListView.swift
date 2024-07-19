import SwiftUI

struct PhotoListView: View {
    var photos: [Photo]
    var loadMoreAction: (() -> Void)?
    var canLoadMore: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            // 显示搜索结果数量
            Text("Found \(photos.count) photos")
                .font(.caption2)
                .padding(.leading)

            List {
                ForEach(Array(zip(photos.indices, photos)), id: \.1.id) { index, photo in
                    NavigationLink(destination: DetailView(photos: photos, initialIndex: photos.firstIndex(where: { $0.id == photo.id }) ?? 0, onDismiss: { _ in })) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                // 第一行：时间 - ObjectName 或者 title
                                Text("\(formatDate(dateTimeOriginal: photo.dateTimeOriginal)) - \(photo.objectName.isEmpty ? photo.title : photo.objectName)")
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                // 第二行：国家 地区 经纬度
                                Text("\(photo.country), \(photo.locality) (\(formatCoordinates(latitude: photo.latitude, longitude: photo.longitude)))")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                // 第三行：拍摄器材 机身和镜头
                                Text(photo.model)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Text(photo.lensModel)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .padding(.vertical, 4)

                            Spacer()

                            if let uiImage = loadImage(from: photo.thumbnailPath350) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(5)
                            } else {
                                Color.gray
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(5)
                            }
                        }
                    }
                }

                // 加载更多按钮
                if canLoadMore, let loadMoreAction = loadMoreAction {
                    Button(action: loadMoreAction) {
                        Text("Load More")
                            .font(.caption2)
                            .padding()
                    }
                }
            }
            .listStyle(PlainListStyle()) // 移除多余的背景和间距
        }
        .padding(.top, 8) // 适当调整顶部间距
    }

    private func formatDate(dateTimeOriginal: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: dateTimeOriginal) {
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return dateFormatter.string(from: date)
        }
        return dateTimeOriginal
    }

    private func formatCoordinates(latitude: Double, longitude: Double) -> String {
        let latString = String(format: "%.2f", abs(latitude))
        let longString = String(format: "%.2f", abs(longitude))
        let latDirection = latitude >= 0 ? "N" : "S"
        let longDirection = longitude >= 0 ? "E" : "W"
        return "\(longString)° \(longDirection) \(latString)° \(latDirection)"
    }

    private func loadImage(from path: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(path).path

        if fileManager.fileExists(atPath: fullPath) {
            return UIImage(contentsOfFile: fullPath)
        } else {
            print("File does not exist at path: \(fullPath)")
            return nil
        }
    }
}
