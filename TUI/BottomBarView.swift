import SwiftUI

struct BottomBarView: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("enableBirdWatching") private var enableBirdWatching = false
    @State private var showSyncStatus: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // 同步状态指示器
            if showSyncStatus && CloudSyncConfiguration.shared.isConfigured {
                SyncStatusIndicator()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
            }
            
            // 主导航栏
            HStack {
                Spacer()
                NavigationLink(destination: NationalView()) {
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.title)
                        .padding()
                }
                
                Spacer()
                NavigationLink(destination: CalendarView()) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.title)
                        .padding()
                }
                
                Spacer()
                NavigationLink(destination: AddImageView()) {
                    Image(systemName: "plus.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(Color("Flare"))
                        .padding()
                }
                
                Spacer()

                NavigationLink(destination: HistoryView()) {
                    Image(systemName: "trophy.circle.fill")
                        .font(.title)
                        .padding()
                }
                Spacer()
                
                if enableBirdWatching {
                    NavigationLink(destination: BirdCountView()) {
                        Image(systemName: "bird.circle.fill")
                            .font(.title)
                            .padding()
                    }
                } else {
                    NavigationLink(destination: SyncView()) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.title)
                            .padding()
                    }
                }
                
                Spacer()
            }
            .foregroundColor(Color("TUIBLUE"))
            .frame(height: 44)
            .background(Color("BGColor"))
        }
        .edgesIgnoringSafeArea(.bottom)
        .colorScheme(.light)
        .onAppear {
            // 检查是否配置了云同步
            showSyncStatus = CloudSyncConfiguration.shared.isConfigured
        }
    }
    
    private func navigateToView<T: View>(_ view: T) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let hostingController = UIHostingController(rootView: view)
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
        }
        presentationMode.wrappedValue.dismiss()
    }
}

struct BottomBarView_Previews: PreviewProvider {
    static var previews: some View {
        BottomBarView()
    }
}
