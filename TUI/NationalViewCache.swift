import Foundation

class NationalViewCache {
    static let shared = NationalViewCache()
    private init() {}
    
    var countries: [CountryData]?
    var lastUpdateTime: Date?
    
    func shouldUpdate() -> Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdate) > 3600 // 1小时更新一次
    }
    
    func update(with newCountries: [CountryData]) {
        countries = newCountries
        lastUpdateTime = Date()
    }
    
    func clear() {
        countries = nil
        lastUpdateTime = nil
    }
}
