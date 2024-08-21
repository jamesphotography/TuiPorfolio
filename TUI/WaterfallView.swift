import SwiftUI

struct WaterfallView: View {
    let photos: [Photo]
    let onPhotoTapped: (Photo) -> Void
    let onNavigate: (NavigationDestination) -> Void
    let loadMore: () -> Void
    let hasMoreImages: Bool
    let selectedIndex: Int?
    
    @AppStorage("enableBirdWatching") private var enableBirdWatching = false
    @State private var birdList: [[String]] = []
    @State private var birdNumbers: [String: Int] = [:]
    
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var previousSelectedIndex: Int?
    
    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        WaterfallItemView(photo: photo,
                                          onPhotoTapped: onPhotoTapped,
                                          onNavigate: onNavigate,
                                          enableBirdWatching: enableBirdWatching,
                                          birdNumber: birdNumbers[photo.objectName])
                            .id(index)
                    }
                }
                .padding(.horizontal, 5)
                
                if !photos.isEmpty {
                    if hasMoreImages {
                        Button(action: loadMore) {
                            Text("Load more ...")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color("TUIBLUE"))
                                .cornerRadius(15)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                    } else {
                        Text("No More Images")
                            .foregroundColor(.white)
                            .padding(10)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .background(Color("TUIBLUE"))
                            .cornerRadius(15)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                    }
                }
            }
            .onChange(of: selectedIndex) { oldValue, newValue in
                if let index = newValue, index != previousSelectedIndex {
                    withAnimation {
                        proxy.scrollTo(index, anchor: .top)
                    }
                    previousSelectedIndex = index
                }
            }
            .onAppear {
                scrollViewProxy = proxy
                if let index = selectedIndex {
                    withAnimation {
                        proxy.scrollTo(index, anchor: .top)
                    }
                }
                loadBirdList()
                if enableBirdWatching {
                    calculateBirdNumbers()
                }
            }
            .onChange(of: enableBirdWatching) { oldValue, newValue in
                if newValue {
                    calculateBirdNumbers()
                } else {
                    birdNumbers.removeAll()
                }
            }
        }
    }
    
    private func loadBirdList() {
        guard let url = Bundle.main.url(forResource: "birdInfo", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let birdList = try? JSONDecoder().decode([[String]].self, from: data) else {
            return
        }
        self.birdList = birdList
    }
    
    private func calculateBirdNumbers() {
        guard enableBirdWatching else { return }
        
        let allObjectNames = SQLiteManager.shared.getAllObjectNames()
        let earliestPhotoTimes = SQLiteManager.shared.getEarliestPhotoTimeForBirds()
        
        let filteredBirdCounts = allObjectNames.filter { objectName, _ in
            birdList.contains { birdNames in
                birdNames.contains(objectName)
            }
        }
        
        let sortedBirdCounts = filteredBirdCounts.compactMap { (objectName, count) -> (String, String)? in
            if let earliestTime = earliestPhotoTimes.first(where: { $0.0 == objectName })?.1 {
                return (objectName, earliestTime)
            }
            return nil
        }.sorted { $0.1 < $1.1 }
        
        for (index, birdInfo) in sortedBirdCounts.enumerated() {
            birdNumbers[birdInfo.0] = index + 1
        }
    }
}

struct WaterfallItemView: View {
    let photo: Photo
    var onPhotoTapped: (Photo) -> Void
    var onNavigate: (NavigationDestination) -> Void
    let enableBirdWatching: Bool
    let birdNumber: Int?
    @State private var imageExists: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                    
                    if imageExists, let uiImage = loadImage(named: photo.thumbnailPath100) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                            .cornerRadius(6)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                    }
                }
                .shadow(radius: 3)
                .onTapGesture {
                    onPhotoTapped(photo)
                }
                
                Button(action: { onNavigate(.objectName(photo.objectName)) }) {
                    Text(birdTitleText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                HStack {
                    Text(formattedDate(photo.dateTimeOriginal))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    Spacer()

                    if !photo.locality.isEmpty {
                        Button(action: { onNavigate(.locality(photo.locality)) }) {
                            Text(truncatedString(photo.area + ", " + photo.locality, limit: 20))
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .frame(height: UIScreen.main.bounds.width / 2 + 36)
        .onAppear {
            checkImageExistence()
        }
    }
    
    private var birdTitleText: String {
        if enableBirdWatching, let number = birdNumber {
            return "No.\(number) \(truncatedString(photo.objectName.isEmpty ? photo.title : photo.objectName, limit: 15))"
        } else {
            return truncatedString(photo.objectName.isEmpty ? photo.title : photo.objectName, limit: 15)
        }
    }
    
    func checkImageExistence() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(photo.thumbnailPath100).path
        imageExists = fileManager.fileExists(atPath: fullPath)
    }
    
    func loadImage(named imageName: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(imageName).path
        if fileManager.fileExists(atPath: fullPath) {
            return UIImage(contentsOfFile: fullPath)
        }
        return nil
    }
    
    func formattedDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = inputFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yy-MM-dd"
            return outputFormatter.string(from: date)
        }
        return "Unknown Date"
    }
    
    func truncatedString(_ text: String, limit: Int) -> String {
        var count = 0
        var index = text.startIndex
        var result = ""
        
        while index < text.endIndex {
            let char = text[index]
            if char.isASCII {
                count += 1
            } else {
                count += 2
            }
            
            if count > limit {
                result += "…"
                break
            }
            
            result.append(char)
            index = text.index(after: index)
        }
        
        return result
    }
}
