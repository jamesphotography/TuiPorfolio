import SwiftUI

@main
struct TUIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var orientation = UIDevice.current.orientation
    @State private var showAddImageView = false
    @State private var receivedURL: URL?

    var body: some Scene {
        WindowGroup {
            GeometryReader { geometry in
                NavigationView {
                    ZStack {
                        Color("BGColor").edgesIgnoringSafeArea(.all)
                        
                        if showAddImageView, let url = receivedURL {
                            AddImageView.handleIncomingURL(url)
                        } else {
                            LandingView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.horizontal, geometry.size.width > 712 ? (geometry.size.width - 712) / 2 : 0)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .onAppear {
                    appDelegate.handleImageImport = { url in
                        handleReceivedURL(url)
                    }
                }
            }
            .onRotate { newOrientation in
                orientation = newOrientation
            }
            .onOpenURL { url in
                handleReceivedURL(url)
            }
        }
    }
    
    private func handleReceivedURL(_ url: URL) {
        print("Received URL: \(url)")
        receivedURL = url
        showAddImageView = true
    }
}
