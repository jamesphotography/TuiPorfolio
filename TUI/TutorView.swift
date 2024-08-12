import SwiftUI

struct TutorView: View {
    let tutorials = [
        Tutorial(title: "Getting Started", url: "https://www.youtube.com/watch?v=example1"),
        Tutorial(title: "Advanced Features", url: "https://www.youtube.com/watch?v=example2"),
        Tutorial(title: "Pro Tips", url: "https://www.youtube.com/watch?v=example3")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Headbar
                HeadBarView(title: NSLocalizedString("Video Tutorials", comment: ""))
                    .padding(.top, geometry.safeAreaInsets.top)
                
                // Main Content
                List(tutorials) { tutorial in
                    Button(action: {
                        if let url = URL(string: tutorial.url) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.blue)
                            Text(tutorial.title)
                        }
                    }
                }
                .background(Color("BGColor"))
                
                // Bottombar
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
    }
}

struct Tutorial: Identifiable {
    let id = UUID()
    let title: String
    let url: String
}

struct TutorView_Previews: PreviewProvider {
    static var previews: some View {
        TutorView()
    }
}
