import SwiftUI
import WebKit

struct BlogView: View {
    @StateObject private var viewModel = BlogViewModel()

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // HeadBar
                HeadBarView(title: NSLocalizedString("Tui's Blog", comment: ""))
                    .padding(.top, geometry.safeAreaInsets.top)
                
                // Main Content
                List(viewModel.articles) { article in
                    NavigationLink(destination: BlogArticleView(url: article.link, title: article.title)) {
                        VStack(alignment: .leading) {
                            Text(article.title)
                                .font(.headline)
                            Text(article.pubDate, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color("BGColor"))
                .overlay(Group {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .foregroundColor(.red)
                    }
                })
                
                // BottomBar
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .edgesIgnoringSafeArea(.all)
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await viewModel.fetchArticles()
            }
        }
    }
}

struct BlogArticleView: View {
    let url: URL
    let title: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // HeadBar
                HeadBarView(title: title, onBackButtonTap: {
                    presentationMode.wrappedValue.dismiss()
                })
                .padding(.top, geometry.safeAreaInsets.top)
                
                // WebView
                WebView(url: url)
                
                // BottomBar
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .edgesIgnoringSafeArea(.all)
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
        }
        .navigationBarHidden(true)
    }
}

class BlogViewModel: ObservableObject {
    @Published var articles: [RSSItem] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let rssURL = URL(string: "https://tui.jamesphotography.com.au/rss.xml")!
    
    @MainActor
    func fetchArticles() async {
        isLoading = true
        errorMessage = ""
        
        do {
            let (data, _) = try await URLSession.shared.data(from: rssURL)
            let parser = RSSParser()
            articles = parser.parse(data: data)
            print("成功获取文章，数量: \(articles.count)")
        } catch {
            errorMessage = "Failed to load articles: \(error.localizedDescription)"
            print("获取文章失败: \(error)")
        }
        
        isLoading = false
    }
}

struct RSSItem: Identifiable {
    let id = UUID()
    let title: String
    let link: URL
    let pubDate: Date
    let description: String
}

class RSSParser: NSObject, XMLParserDelegate {
    private var items: [RSSItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    
    func parse(data: Data) -> [RSSItem] {
        items = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title": currentTitle += string
        case "link": currentLink += string
        case "description": currentDescription += string
        case "pubDate": currentPubDate += string
        default: break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            let item = RSSItem(title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                               link: URL(string: currentLink)!,
                               pubDate: dateFormatter.date(from: currentPubDate) ?? Date(),
                               description: currentDescription.trimmingCharacters(in: .whitespacesAndNewlines))
            items.append(item)
        }
    }
}
