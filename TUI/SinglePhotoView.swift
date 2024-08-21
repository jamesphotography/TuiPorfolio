import SwiftUI

struct SinglePhotoView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isZoomedIn: Bool = false
    @Environment(\.presentationMode) var presentationMode
    @State private var orientation = UIDevice.current.orientation

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                VStack {
                    Spacer()
                    ImageScrollView(image: image, geometry: geometry)
                    Spacer()
                }

                VStack {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding()
                        Spacer()
                    }
                    Spacer()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                self.orientation = UIDevice.current.orientation
                self.scale = 1.0
                self.lastScale = 1.0
                self.offset = .zero
                self.lastOffset = .zero
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
    }
}

struct ImageScrollView: UIViewRepresentable {
    var image: UIImage
    var geometry: GeometryProxy

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 10.0
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .black

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.frame = CGRect(x: 0, y: 0, width: geometry.size.width, height: geometry.size.height)
        imageView.center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        scrollView.addSubview(imageView)
        scrollView.contentSize = imageView.frame.size

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if let imageView = uiView.subviews.first as? UIImageView {
            imageView.frame = CGRect(x: 0, y: 0, width: geometry.size.width, height: geometry.size.height)
            imageView.center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ImageScrollView

        init(_ parent: ImageScrollView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.subviews.first
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            if let imageView = scrollView.subviews.first as? UIImageView {
                let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0.0)
                let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0.0)
                imageView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX, y: scrollView.contentSize.height * 0.5 + offsetY)
            }
        }
    }
} 
