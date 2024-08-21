import SwiftUI

struct LandingView: View {
    @State private var activeDot = 0
    @State private var isActive = false
    @State private var todaysQuote: Quote?
    @State private var userName: String = ""
    @State private var appName: String = ""
    @State private var showLanding = true
    @State private var isFirstLaunch = true
    @State private var hasPhotos: Bool = false
    
    var body: some View {
        Group {
            if showLanding {
                landingContent
            } else if !hasPhotos {
                OnboardingView(isFirstLaunch: $isFirstLaunch)
            } else {
                ContentView()
            }
        }
        .onAppear {
            loadTodaysQuote()
            loadUserName()
            startDotAnimation()
            checkFirstLaunch()
            checkForPhotos()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    self.showLanding = false
                }
            }
        }
    }
    
    var landingContent: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 0)
                    
                    VStack(spacing: 10) {
                        Spacer(minLength: 44)
                        Text("Tui")
                            .font(.system(size: 48))
                            .fontWeight(.thin)
                            .foregroundColor(Color("TUIBLUE"))
                            .padding(.bottom, 5)
                        
                        Text("\(userName)'s Portfolio")
                            .font(.title)
                            .fontWeight(.thin)
                            .foregroundColor(Color("TUIBLUE"))
                            .padding(5)
                        Spacer(minLength: 44)
                        Image("tuiapp")
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(250, geometry.size.width * 0.8))
                        Spacer(minLength: 20)
                        
                        if let todaysQuote = todaysQuote {
                            VStack {
                                HStack{
                                    Text(todaysQuote.quote)
                                        .font(.caption)
                                        .fontWeight(.thin)
                                        .foregroundColor(Color("TUIBLUE"))
                                        .multilineTextAlignment(.leading)
                                        .padding(20)
                                }
                                HStack {
                                    Spacer()
                                    Text("- \(todaysQuote.author)")
                                        .font(.caption)
                                        .fontWeight(.thin)
                                        .foregroundColor(Color("TUIBLUE"))
                                }
                                .padding(.horizontal,20)
                            }
                            .padding(.horizontal, UIScreen.main.bounds.width * 0.1)
                            .padding(.vertical)
                        }
                        
                        Spacer()
                        HStack(spacing: 10) {
                            ForEach(0..<4, id: \.self) { index in
                                Circle()
                                    .frame(width: 5, height: 5)
                                    .foregroundColor(activeDot == index ? .gray : .gray.opacity(0.5))
                                    .scaleEffect(activeDot == index ? 1.2 : 1.0)
                                    .animation(Animation.linear(duration: 0.5).repeatForever(autoreverses: true), value: activeDot)
                            }
                        }
                        Spacer(minLength: 44)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height)
                    .frame(minHeight: geometry.size.height)
                    
                    Spacer()
                }
                .frame(width: geometry.size.width)
            }
        }
        .background(Color("BGColor").edgesIgnoringSafeArea(.all))
    }
    
    func loadTodaysQuote() {
        let quoteManager = QuoteManager.shared
        todaysQuote = quoteManager.getTodaysFullQuote()
    }
    
    func loadUserName() {
        if let userName = UserDefaults.standard.string(forKey: "userName") {
            self.userName = userName
        }
    }
    
    func startDotAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.activeDot = (self.activeDot + 1) % 4
        }
    }
    
    func checkFirstLaunch() {
        isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    }
    
    func checkForPhotos() {
        let photoCount = SQLiteManager.shared.getAllPhotos().count
        hasPhotos = photoCount > 0
        if hasPhotos {
            UserDefaults.standard.set(false, forKey: "isFirstLaunch")
        }
    }
}

struct Settings: Codable {
    var userName: String
}
