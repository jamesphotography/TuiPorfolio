import Foundation

class HotSearchManager {
    static let shared = HotSearchManager()
    private let userDefaultsKey = "hotSearches"
    private let maxHotSearches = 10

    private init() {}

    func getHotSearches() -> [String] {
        return UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }

    func addHotSearch(_ keyword: String) {
        var hotSearches = getHotSearches()
        if let index = hotSearches.firstIndex(of: keyword) {
            hotSearches.remove(at: index)
        }
        hotSearches.insert(keyword, at: 0)
        if hotSearches.count > maxHotSearches {
            hotSearches.removeLast()
        }
        UserDefaults.standard.setValue(hotSearches, forKey: userDefaultsKey)
    }
}
