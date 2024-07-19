import SwiftUI

@main
struct TUIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var orientation = UIDevice.current.orientation

    var body: some Scene {
        WindowGroup {
            GeometryReader { geometry in
                NavigationView {
                    ZStack {
                        Color("BGColor").edgesIgnoringSafeArea(.all)
                        
                        LandingView()
                            .frame(maxWidth: min(geometry.size.width, 600))
                            .frame(maxHeight: geometry.size.height)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
            .onRotate { newOrientation in
                orientation = newOrientation
            }
        }
    }
}
