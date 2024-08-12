import SwiftUI
import StoreKit

struct SettingsView: View {
    @AppStorage("userName") private var userName = "Jo"
    @AppStorage("sortByShootingTime") private var sortByShootingTime = false
    @AppStorage("useSingleColumnLayout") private var useSingleColumnLayout = false
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
                    HStack{
                        Section(header: Text("")) {
                            TextField("User Name", text: $userName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(minWidth: 200, maxWidth: 260)
                            Spacer()
                            Button(action: saveSettings) {
                                Text("Save")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color("TUIBLUE"))
                                    .cornerRadius(10)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    Section(header: Text("Photo Sorting & Layout")) {
                        Toggle("Sort by Shooting Time", isOn: $sortByShootingTime)
                        Toggle("Use Single Column Layout", isOn: $useSingleColumnLayout)
                        Toggle("Enable Bird Watching", isOn: $enableBirdWatching)
                    }
                    
                    Section(header: Text("Share Options")) {
                        Toggle("Share with EXIF", isOn: $shareWithExif)
                        Toggle("Share with GPS", isOn: $shareWithGPS)
                        Toggle("Omit Camera Brand", isOn: $omitCameraBrand)
                    }
                    
                    Section(header: Text("More Options")) {
                        NavigationLink(destination: BackupView()) {
                            Text("Backup & Restore")
                        }
                        NavigationLink(destination: QuotesView()) {
                            Text("Photography Quotes")
                        }
                        NavigationLink(destination: CameraCountView()) {
                            Text("Camera Count")
                        }
                        NavigationLink(destination: LensCountView()) {
                            Text("Lens Count")
                        }
                    }
                    
                    Section(header: Text("Help & More")) {
                        NavigationLink(destination: BirdNameListView()) {
                            Text("Bird Name Match")
                        }
                        NavigationLink(destination: BeginnerView()) {
                            Text("Beginner's Guide")
                        }
                        NavigationLink(destination: TutorView()) {
                            Text("Video Tutorials")
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
