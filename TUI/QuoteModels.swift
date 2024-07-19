import Foundation

struct Quote: Identifiable, Codable {
    var id: String
    var quote: String
    var author: String
    
    // 自定义初始化方法
    init(id: String, quote: String, author: String) {
        self.id = id
        self.quote = quote
        self.author = author
    }

    // 用于解码 JSON 的初始化方法
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = String(idInt)
        } else {
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected to decode String or Int for id"))
        }
        quote = try container.decode(String.self, forKey: .quote)
        author = try container.decode(String.self, forKey: .author)
    }

    // 用于编码为 JSON 的方法
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(quote, forKey: .quote)
        try container.encode(author, forKey: .author)
    }

    // 定义 JSON 的键值
    private enum CodingKeys: String, CodingKey {
        case id
        case quote
        case author
    }
}


class QuoteManager {
    static let shared = QuoteManager()
    private var quotes: [Quote] = []
    private var todaysQuote: Quote?
    
    private init() {
        loadQuotes()
    }
    
    private func loadQuotes() {
        let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        var fileName = "CH-photography_quotes"
        
        switch deviceLanguage {
        case "zh":
            if Locale.current.region?.identifier == "TW" || Locale.current.region?.identifier == "HK" {
                fileName = "TW-photography_quotes"
            }
        case "en":
            fileName = "EN_photography_quotes"
        default:
            fileName = "EN_photography_quotes"
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
    
    private func selectTodaysQuote() {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
        if !quotes.isEmpty {
            let index = dayOfYear % quotes.count
            todaysQuote = quotes[index]
        }
    }
    
    func getTodaysQuote() -> String {
        if let quote = todaysQuote {
            return "\(quote.quote)"
        } else {
            return "Photography is the story I fail to put into words."
        }
    }
}
