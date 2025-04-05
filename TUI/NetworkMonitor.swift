import Foundation
import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    var isConnected: Bool = false
    var isExpensive: Bool = false
    var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            self?.isExpensive = path.isExpensive
            
            if path.usesInterfaceType(.wifi) {
                self?.connectionType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                self?.connectionType = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                self?.connectionType = .ethernet
            } else {
                self?.connectionType = .unknown
            }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .networkStatusChanged, object: nil)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func isWifiConnected() -> Bool {
        return isConnected && connectionType == .wifi
    }
    
    func canSync() -> Bool {
        let syncOnWifiOnly = UserDefaults.standard.bool(forKey: "cloudSyncOnWifiOnly")
        
        if syncOnWifiOnly {
            return isWifiConnected()
        } else {
            return isConnected
        }
    }
    
    deinit {
        monitor.cancel()
    }
}

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("com.tuiportfolio.networkStatusChanged")
}
