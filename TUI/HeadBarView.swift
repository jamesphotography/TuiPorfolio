import SwiftUI
import UIKit

struct HeadBarView: View {
    @Environment(\.presentationMode) var presentationMode
    var title: String
    var countryCode: String?
    var onBackButtonTap: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 0) {
            // Left section
            HStack(spacing: 10) {
                Button(action: {
                    navigateToView(ContentView())
                }) {
                    Image("tuiapp")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }
                .foregroundColor(Color("TUIBLUE"))

                Button(action: {
                    if let onBackButtonTap = onBackButtonTap {
                        onBackButtonTap()
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
            }
            .frame(width: 80, alignment: .leading)

            // Center section
            HStack(spacing: 4) {
                if let code = countryCode {
                    FlagView(country: code)
                        .frame(width: 20, height: 20)
                }
                Text(title)
                    .font(.title2)
                    .fontWeight(.light)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)

            // Right section
            HStack(spacing: 10) {
                NavigationLink(destination: SearchView()) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                }
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                }
            }
            .frame(width: 80, alignment: .trailing)
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .background(Color("BGColor"))
        .foregroundColor(Color("TUIBLUE"))
    }
    
    private func navigateToView<T: View>(_ view: T) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let hostingController = UIHostingController(rootView: view)
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
        }
    }
}

struct FlagView: View {
    let country: String
    
    var body: some View {
        Text(country.flagEmoji)
            .font(.system(size: 20))
    }
}

extension String {
    var flagEmoji: String {
        let base : UInt32 = 127397
        var s = ""
        for v in self.uppercased().unicodeScalars {
            s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
        }
        return String(s)
    }
}

struct HeadBarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HeadBarView(title: "Jo's Portfolio", countryCode: "US")
        }
        .previewLayout(.sizeThatFits)
    }
}
