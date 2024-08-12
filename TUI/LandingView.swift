import SwiftUI

struct LandingView: View {
    @State private var activeDot = 0
    @State private var isActive = false
    @State private var todaysQuote: Quote?
    @State private var userName: String = ""
    @State private var appName: String = ""
    @State private var showLanding = true

    var body: some View {
        Group {
            if showLanding {
                landingContent
            } else {
                ContentView()
            }
        }
        .onAppear {
            loadTodaysQuote()
            loadUserName()
            startDotAnimation()
            
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
                    
                    VStack(spacing: 20) {
                        Text("Tui")
                            .font(.largeTitle)
                            .fontWeight(.thin)
                            .foregroundColor(Color("TUIBLUE"))
                        
                        Text("\(userName) Portfolio")
                            .font(.caption)
                            .fontWeight(.thin)
                            .foregroundColor(Color("TUIBLUE"))
                        
                        Image("tuiapp")
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(250, geometry.size.width * 0.8))
                        
                        if let todaysQuote = todaysQuote {
                            VStack {
                                Text(todaysQuote.quote)
                                    .font(.caption)
                                    .fontWeight(.thin)
                                    .foregroundColor(Color("TUIBLUE"))
                                    .multilineTextAlignment(.leading)
                                    .padding(10)
                                Text("- \(todaysQuote.author)")
                                    .font(.caption)
                                    .fontWeight(.thin)
                                    .foregroundColor(Color("TUIBLUE"))
                            }
                            .padding(.horizontal, UIScreen.main.bounds.width * 0.15)
                            .padding(.vertical)
                        }
                        
                        HStack(spacing: 10) {
                            ForEach(0..<4) { index in
                                Circle()
                                    .frame(width: 5, height: 5)
                                    .foregroundColor(activeDot == index ? .gray : .gray.opacity(0.5))
                                    .scaleEffect(activeDot == index ? 1.2 : 1.0)
                                    .animation(Animation.linear(duration: 0.5).repeatForever(autoreverses: true), value: activeDot)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height)
                    .frame(minHeight: geometry.size.height)
                    
                    Spacer(minLength: 0)
                }
                .frame(width: geometry.size.width)
            }
        }
        .background(Color("BGColor").edgesIgnoringSafeArea(.all))
    }
    
    func loadTodaysQuote() {
        let quoteManager = QuoteManager.shared
        let quoteString = quoteManager.getTodaysQuote()
        todaysQuote = Quote(id: "0", quote: quoteString, author: "Unknown")
    }
    
    func loadUserName() {
        let fileURL = getDocumentsDirectory().appendingPathComponent("settings.json")
        if let data = try? Data(contentsOf: fileURL) {
            if let settings = try? JSONDecoder().decode(Settings.self, from: data) {
                userName = settings.userName
            }
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func startDotAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.activeDot = (self.activeDot + 1) % 4
        }
    }
}

struct Settings: Codable {
    var userName: String
}
