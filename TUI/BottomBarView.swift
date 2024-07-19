import SwiftUI

struct BottomBarView: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("enableBirdWatching") private var enableBirdWatching = false
    
    var body: some View {
        HStack {
            Spacer()
            Button(action: {
                navigateToView(ContentView())
            }) {
                Image(systemName: "house.circle.fill")
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
                    .font(.title)
                    .padding()
            }
            
            Spacer()
            NavigationLink(destination: NationalView()) {
                Image(systemName: "map.circle.fill")
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
                NavigationLink(destination: QuotesView()) {
                    Image(systemName: "book.closed.circle.fill")
                        .font(.title)
                        .padding()
                }
            }
            
            Spacer()
        }
        .foregroundColor(Color("TUIBLUE"))
        .frame(height: 44)
        .background(Color("BGColor"))
        .edgesIgnoringSafeArea(.bottom)
        .colorScheme(.light)
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
