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
    @State private var showingCloudSyncView = false
    @State private var showClearCloudDataView = false
    @State private var showVerificationView = false
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Headbar
                HeadBarView(title: NSLocalizedString("Settings", comment: ""))
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
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(7)
                                    .background(Color("TUIBLUE"))
                                    .cornerRadius(3)
                                    .frame(width: 60)
                            }
                        }
                    }
                    Section(header: Text("Photo Sorting & Layout")) {
                        Toggle("Sort by Shooting Time", isOn: $sortByShootingTime)
                        Toggle("Use Single Column Layout", isOn: $useSingleColumnLayout)
                        Toggle("Enable Bird Watching", isOn: $enableBirdWatching)
                        Toggle("Share with EXIF", isOn: $shareWithExif)
                        Toggle("Share with GPS", isOn: $shareWithGPS)
                        Toggle("Omit Camera Brand", isOn: $omitCameraBrand)
                    }
                    
                    Section(header: Text("Cloud Sync")) {
                        Button(action: {
                            showingCloudSyncView = true
                        }) {
                            HStack {
                                Image(systemName: "cloud.fill")
                                    .foregroundColor(Color("TUIBLUE"))
                                Text("Sync Photos to Cloud")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Section(header: Text("云同步测试")) {
                        
                        Button(action: {
                                showVerificationView = true
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundColor(Color("TUIBLUE"))
                                    Text("验证同步状态")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                        
                        Button(action: {
                            showClearCloudDataView = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text("清空云端数据")
                                    .foregroundColor(.red)
                            }
                        }
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
                        if enableBirdWatching {
                            NavigationLink(destination: YearlyBirdReportView()) {
                                Text("Yearly Bird Report")
                            }
                        }
                        NavigationLink(destination: BirdNameListView()) {
                            Text("Bird Name Match")
                        }
                        NavigationLink(destination: BeginnerView()) {
                            Text("Beginner's Guide")
                        }
                    }
                    
                    Section(header: Text("App Feedback")) {
                        Button(action: rateApp) {
                            HStack {
                                Text("Rate App")
                                Spacer()
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                }
                .padding(8)
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
            .sheet(isPresented: $showingCloudSyncView) {
                CloudSyncView()
            }
            .sheet(isPresented: $showClearCloudDataView) {
                ClearCloudDataView()
            }
            .sheet(isPresented: $showVerificationView) {
                CloudSyncVerificationView()
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    private func saveSettings() {
        showingSaveMessage = true
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    @MainActor
    private func rateApp() {
        requestReview()
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
