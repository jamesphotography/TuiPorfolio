import SwiftUI

struct OnboardingView: View {
    @Binding var isFirstLaunch: Bool
    @State private var showBackupRestore = false
    @State private var currentStep = 0
    @State private var showAddImageView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome to Tui!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your personal photo portfolio")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                Spacer()
                
                TabView(selection: $currentStep) {
                    welcomeView
                        .tag(0)
                    
                    featureView
                        .tag(1)
                    
                    addPhotoView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                Spacer()
                
                if currentStep < 2 {
                    Button(action: {
                        withAnimation {
                            currentStep += 1
                        }
                    }) {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color("TUIBLUE"))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                Button(action: {
                    showBackupRestore = true
                }) {
                    Text("Restore from Backup")
                        .font(.headline)
                        .foregroundColor(Color("TUIBLUE"))
                }
                .padding()
            }
            .padding()
            .sheet(isPresented: $showBackupRestore) {
                BackupView()
            }
            .fullScreenCover(isPresented: $showAddImageView) {
                AddImageView()
            }
        }
        
    }
    
    var welcomeView: some View {
        VStack(spacing: 20) {
            Image("tuiapp")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
            
            Text("Welcome to Tui")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your personal photo portfolio app")
                .font(.subheadline)
                .foregroundColor(Color("TUIBLUE"))
        }
    }

    
    var featureView: some View {
        VStack(alignment: .leading, spacing: 15) {
            FeatureRow(iconName: "photo.on.rectangle", text: NSLocalizedString("Organize your photos", comment: "Feature description for photo organization"))
            FeatureRow(iconName: "globe.asia.australia.fill", text: NSLocalizedString("View photos by location", comment: "Feature description for location-based photo viewing"))
            FeatureRow(iconName: "calendar", text: NSLocalizedString("Browse photos by date", comment: "Feature description for date-based photo browsing"))
            FeatureRow(iconName: "star", text: NSLocalizedString("Rate your favorite shots", comment: "Feature description for photo rating"))
        }
    }
    
    var addPhotoView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(Color("TUIBLUE"))
            
            Text("Add Your First Photo")
                .font(.title)
                .fontWeight(.bold)
            
            Text("To get started, let's add your first photo to your portfolio.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button(action: {
                showAddImageView = true
            }) {
                Text("Add Photo")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color("TUIBLUE"))
                    .cornerRadius(10)
            }
        }
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        isFirstLaunch = false
    }
}

struct FeatureRow: View {
    let iconName: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: iconName)
                .foregroundColor(Color("TUIBLUE"))
                .font(.title2)
            Text(text)
                .font(.body)
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isFirstLaunch: .constant(true))
    }
}
