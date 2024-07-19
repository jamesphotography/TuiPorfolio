import SwiftUI
import UIKit

struct HeadBarView: View {
    @Environment(\.presentationMode) var presentationMode
    var title: String
    var countryCode: String?
    var onBackButtonTap: (() -> Void)?

    var body: some View {
        HStack {
            Button(action: {
                if let navController = getNavigationController() {
                    for (index, controller) in navController.viewControllers.enumerated() {
                        print("\(index): \(type(of: controller))")
                    }
                }
                
                if let onBackButtonTap = onBackButtonTap {
                    onBackButtonTap()
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.footnote)
                    .padding()
            }

            Spacer()

            HStack(spacing: 8) {
                if let code = countryCode {
                    FlagView(country: code)
                        .frame(width: 30, height: 20)
                }
                Text(title)
                    .font(.title2)
                    .fontWeight(.thin)
                    .foregroundColor(Color("TUIBLUE"))
            }

            Spacer()

            HStack {
                NavigationLink(destination: SearchView()) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .padding(.trailing, 10)
                }
                .foregroundColor(Color("TUIBLUE"))

                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .padding(.trailing, 10)
                }
                .foregroundColor(Color("TUIBLUE"))
            }
        }
        .frame(height: 44)
        .background(Color("BGColor"))
    }
}

extension View {
    func getNavigationController() -> UINavigationController? {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = scene?.windows.first
        return window?.rootViewController as? UINavigationController
    }
}

struct FlagView: View {
    let country: String
    
    var body: some View {
        Text(country.flagEmoji)
            .font(.system(size: 30))
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
