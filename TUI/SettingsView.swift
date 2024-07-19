import SwiftUI

struct SettingsView: View {
    @AppStorage("userName") private var userName = "Jo"
    @AppStorage("sortByShootingTime") private var sortByShootingTime = false
    @AppStorage("useWaterfallLayout") private var useWaterfallLayout = false
    @AppStorage("enableBirdWatching") private var enableBirdWatching = false
    @AppStorage("shareWithExif") private var shareWithExif = false
    @AppStorage("shareWithGPS") private var shareWithGPS = false
    @AppStorage("omitCameraBrand") private var omitCameraBrand = false
    @State private var showingSaveMessage = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Headbar
                HeadBarView(title: "Settings")
                    .padding(.top, geometry.safeAreaInsets.top)
                
                // Main
                Form {
                    Section(header: Text("User Name")) {
                        TextField("User Name", text: $userName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Section(header: Text("Photo Sorting & Layout")) {
                        Toggle("Sort by Shooting Time", isOn: $sortByShootingTime)
                        Toggle("Use Waterfall Layout", isOn: $useWaterfallLayout)
                        Toggle("Enable Bird Watching", isOn: $enableBirdWatching)
                    }
                    
                    Section(header: Text("Share Options")) {
                        Toggle("Share with EXIF", isOn: $shareWithExif)
                        Toggle("Share with GPS", isOn: $shareWithGPS)
                        Toggle("Omit Camera Brand", isOn: $omitCameraBrand)
                    }
                    
                    Button(action: saveSettings) {
                        Text("Save Settings")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color("TUIBLUE"))
                            .cornerRadius(10)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                    }
                    
                    Section(header: Text("More Options")) {
                        NavigationLink(destination: HistoryView()) {
                            Text("Photography Journey")
                        }
                        NavigationLink(destination: Project365View()) {
                            Text("Project365")
                        }
                        NavigationLink(destination: QuotesView()) {
                            Text("Photography Quotes")
                        }
                        NavigationLink(destination: BulkImportView()) {
                            Text("Bulk Import")
                        }
                        NavigationLink(destination: CameraCountView()) {
                            Text("Camera Count")
                        }
                        NavigationLink(destination: LensCountView()) {
                            Text("Lens Count")
                        }
                    }
                    
                    Section(header: Text("Bird Watching")){
                        NavigationLink(destination: BirdCountView()) {
                            Text("Bird Count")
                        }
                        NavigationLink(destination: BirdNameListView()) {
                            Text("Bird Name Match")
                        }
                    }
                }
                .padding()
                .background(Color("BGColor"))
                
                // Bottombar
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
            .alert(isPresented: $showingSaveMessage) {
                Alert(
                    title: Text("Settings Saved"),
                    message: Text("Your settings have been saved successfully."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
    
    private func saveSettings() {
        showingSaveMessage = true
        //print("Settings saved: sortByShootingTime = \(sortByShootingTime), useWaterfallLayout = \(useWaterfallLayout), enableBirdWatching = \(enableBirdWatching), shareWithExif = \(shareWithExif), shareWithGPS = \(shareWithGPS), omitCameraBrand = \(omitCameraBrand)")
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("com.yourapp.settingsChanged")
}
