// TUIApp.swift

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
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, geometry.size.width > 712 ? (geometry.size.width - 712) / 2 : 0)
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
