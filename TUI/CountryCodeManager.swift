import Foundation

struct Country: Codable {
    let name: String
    let code: String
    let name_zh_cn: String
    let name_zh_tw: String
}

class CountryCodeManager {
    static let shared = CountryCodeManager()
    private var countries: [Country] = []
    
    private init() {
        loadCountryCodes()
    }
    
    private func loadCountryCodes() {
        guard let url = Bundle.main.url(forResource: "countriesCode", withExtension: "json") else {
            print("DEBUG: countriesCode.json not found")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            countries = try JSONDecoder().decode([Country].self, from: data)
        } catch {
            print("DEBUG: Error loading country codes: \(error)")
        }
    }
    
    func getCountryCode(for countryName: String) -> String? {
        let code = countries.first { $0.name.lowercased() == countryName.lowercased() }?.code
        //print("DEBUG: Getting country code for '\(countryName)': \(code ?? "not found")")
        return code
    }
    
    func getCountryName(for code: String, languageCode: String = "en") -> String? {
        guard let country = countries.first(where: { $0.code.lowercased() == code.lowercased() }) else {
            print("DEBUG: Country not found for code '\(code)'")
            return nil
        }
        
        let name: String
        switch languageCode {
        case "zh-Hans", "zh-CN", "zh":
            name = country.name_zh_cn
        case "zh-Hant", "zh-TW":
            name = country.name_zh_tw
        default:
            name = country.name
        }
        return name
    }
    
    func getAllCountries() -> [Country] {
        return countries
    }
}
