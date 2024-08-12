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
        // 使用 GeometryReader 来获取设备尺寸信息
        GeometryReader { geometry in
            // 使用 ScrollView 使内容可滚动
            ScrollView {
                // 主要内容的垂直排列
                VStack(spacing: 20) {
                    // 顶部空白
                    Spacer(minLength: 0)
                    
                    // 内容区域
                    VStack(spacing: 10) {
                        Spacer(minLength: 44)
                        // 应用名称 "Tui"
                        Text("Tui")
                            .font(.system(size: 48))
                            .fontWeight(.thin)
                            .foregroundColor(Color("TUIBLUE"))
                            .padding(.bottom, 5)
                        
                        // 用户名和 "Portfolio" 文字
                        Text("\(userName)'s Portfolio")
                            .font(.title)
                            .fontWeight(.thin)
                            .foregroundColor(Color("TUIBLUE"))
                            .padding(5)
                        Spacer(minLength: 44)
                        // 应用图标
                        Image("tuiapp")
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(250, geometry.size.width * 0.8))
                        Spacer(minLength: 20)
                        // 今日引用区域
                        VStack {
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
                                    .padding(.horizontal,20)  // 可選，根據需要調整水平邊距
                                }
                                .padding(.horizontal, UIScreen.main.bounds.width * 0.1)
                                .padding(.vertical)
                            }
                            
                        }
                        // 底部动画圆点
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
                    // 设置内容区域的框架
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height)
                    .frame(minHeight: geometry.size.height)
                    
                    // 底部空白
                    Spacer()
                }
                // 设置整个 ScrollView 内容的宽度
                .frame(width: geometry.size.width)
            }
        }
        // 设置背景颜色
        .background(Color("BGColor").edgesIgnoringSafeArea(.all))
    }
    
    struct Settings: Codable {
        var userName: String
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
}

struct Settings: Codable {
    var userName: String
}

