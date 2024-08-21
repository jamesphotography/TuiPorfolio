import Foundation

class BirdCountCache {
    static let shared = BirdCountCache()
    private init() {}
    
    var birdCounts: [(String, Int, String, String)]?
    var lastUpdateTime: Date?
    
    func shouldUpdate() -> Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdate) > 3600 // 1小时更新一次
    }
    
    func update(with newCounts: [(String, Int, String, String)]) {
        birdCounts = newCounts
        lastUpdateTime = Date()
    }
    
    func clear() {
        birdCounts = nil
        lastUpdateTime = nil
    }
}
