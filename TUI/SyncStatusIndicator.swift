import SwiftUI

struct SyncStatusIndicator: View {
    @State private var syncStatus: PhotoSyncStatus?
    @State private var isSyncing: Bool = false
    @State private var isAnimating: Bool = false
    
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            if isSyncing {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                    .onAppear { isAnimating = true }
                    .onDisappear { isAnimating = false }
                
                Text("同步中")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            } else if let status = syncStatus, status.pendingChanges > 0 {
                Image(systemName: "cloud.badge.exclamationmark")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                
                Text("\(status.pendingChanges)待同步")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            } else if let status = syncStatus, let _ = status.lastSyncTime {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
                
                Text("已同步")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Text("未同步")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.2))
        )
        .onAppear {
            updateStatus()
        }
        .onReceive(timer) { _ in
            updateStatus()
        }
    }
    
    private func updateStatus() {
        isSyncing = CloudSyncManager.shared.isSyncing
        
        if !isSyncing {
            syncStatus = SQLiteManager.shared.getSyncStatus()
        }
    }
}

struct SyncStatusIndicator_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
            SyncStatusIndicator()
        }
        .previewLayout(.sizeThatFits)
    }
}
