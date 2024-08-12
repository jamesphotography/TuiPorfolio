import SwiftUI

struct QuotesView: View {
    @State private var quotes: [Quote] = []
    @State private var todaysQuote: Quote?
    @State private var todaysQuoteIndex: Int?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 顶部导航栏
                HeadBarView(title: NSLocalizedString("Photographic Quotes", comment: ""))
                    .padding(.top, geometry.safeAreaInsets.top)

                // 主体内容区域
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer() // 上部 Spacer
                        
                        // 更新的 QuoteView 使用
                        if let todaysQuote = todaysQuote, let index = todaysQuoteIndex {
                            QuoteView(quote: todaysQuote.quote, author: todaysQuote.author, index: index + 1)
                                .frame(height: geometry.size.height * 0.6) // 设置高度为屏幕高度的60%
                        }

                        
                        Spacer() // 下部 Spacer
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(Color("BGColor"))
                }

                // 底部导航栏
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            loadQuotes()
        }
    }

    func loadQuotes() {
        let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        var fileName = "CH-photography_quotes"
        
        switch deviceLanguage {
        case "zh":
            // 检查是否为繁体中文
            if Locale.current.region?.identifier == "TW" || Locale.current.region?.identifier == "HK" {
                fileName = "TW-photography_quotes"
            }
        case "en":
            fileName = "EN_photography_quotes"
        default:
            fileName = "EN_photography_quotes" // 默认使用英文
        }

        if let url = Bundle.main.url(forResource: fileName, withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                quotes = try decoder.decode([Quote].self, from: data)
                selectTodaysQuote()
            } catch {
                print("Error loading quotes: \(error)")
            }
        } else {
            print("Error: Could not find file \(fileName).json")
        }
    }

    // 选择今天的名言
    func selectTodaysQuote() {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
        if !quotes.isEmpty {
            todaysQuoteIndex = dayOfYear % quotes.count
            todaysQuote = quotes[todaysQuoteIndex!]
        }
    }
}

struct QuoteView: View {
    var quote: String
    var author: String
    var index: Int
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                VStack {
                    Spacer(minLength: 20)
                    Image("tuiblueapp")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                    Spacer()
                    HStack {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.leading, 20)
                        Spacer()
                    }
                    Spacer()
                    VStack(spacing: 10) {
                        Text(quote)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 30)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 10)
                        HStack{
                            Spacer()
                            Text("- \(author)")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.trailing, 20)
                        }

                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "quote.closing")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.trailing, 20)
                    }
                }
                .padding(.vertical, 20)
                .background(Color("TUIBLUE"))
                .cornerRadius(15)
                .shadow(radius: 10)
                Spacer()
            }
        }
    }
}

struct QuotesView_Previews: PreviewProvider {
    static var previews: some View {
        QuotesView()
    }
}
