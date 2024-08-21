import SwiftUI

struct TutorView: View {
    let videoId = "UNip0nUr7SQ" // 替换为你想要显示的视频 ID
    @State private var videoTitle: String = ""
    @State private var errorMessage: String?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Headbar
                HeadBarView(title: NSLocalizedString("Video Tutorial", comment: ""))
                    .padding(.top, geometry.safeAreaInsets.top)
                
                // Main Content
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    VStack {
                        Text(videoTitle)
                            .font(.headline)
                            .padding()
                        
                        WebView(url: URL(string: "https://www.youtube.com/embed/\(videoId)")!)
                            .frame(height: 300)
                    }
                }
                
                // Bottombar
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor"))
        }
        .ignoresSafeArea(edges: .vertical)
        .navigationBarHidden(true)
        .onAppear {
            fetchVideoDetails()
        }
    }
    
    func fetchVideoDetails() {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "YouTubeAPIKey") as? String, !apiKey.isEmpty else {
            self.errorMessage = "YouTube API Key not found or empty"
            return
        }
        
        let urlString = "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=\(videoId)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received"
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let items = json["items"] as? [[String: Any]],
                   let firstItem = items.first,
                   let snippet = firstItem["snippet"] as? [String: Any],
                   let title = snippet["title"] as? String {
                    DispatchQueue.main.async {
                        self.videoTitle = title
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to parse video details"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error parsing JSON: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}
