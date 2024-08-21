import SwiftUI
import UIKit

struct ZoomInView: View {
    var imagePath: String
    @State private var image: UIImage? = nil
    @Environment(\.presentationMode) var presentationMode
    @State private var orientation = UIDevice.current.orientation
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.5).edgesIgnoringSafeArea(.all) // 背景颜色为半透明

                if let uiImage = image {
                    let aspectRatio = uiImage.size.height / uiImage.size.width
                    let width = geometry.size.width
                    let height = width * aspectRatio

                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: width * scale, height: height * scale)
                        .offset(x: offset.width, y: offset.height)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    self.scale = value.magnitude
                                }
                                .onEnded { value in
                                    self.scale = value.magnitude
                                }
                                .simultaneously(with:
                                    DragGesture()
                                        .onChanged { value in
                                            self.offset = CGSize(width: value.translation.width + self.lastOffset.width, height: value.translation.height + self.lastOffset.height)
                                        }
                                        .onEnded { value in
                                            self.lastOffset = self.offset
                                        }
                                )
                        )
                        .gesture(
                            TapGesture(count: 2).onEnded {
                                // 双击恢复初始状态
                                withAnimation {
                                    self.scale = 1.0
                                    self.offset = .zero
                                    self.lastOffset = .zero
                                }
                            }
                        )
                        .gesture(
                            TapGesture(count: 1).onEnded {
                                // 单击返回上一页
                                presentationMode.wrappedValue.dismiss()
                            }
                        )
                        .onRotate { newOrientation in
                            orientation = newOrientation
                            print("New orientation: \(newOrientation.rawValue)")
                            if newOrientation.isPortrait {
                                print("Device is in portrait mode.")
                            } else if newOrientation.isLandscape {
                                print("Device is in landscape mode.")
                            } else {
                                print("Unknown orientation.")
                            }
                            refreshImage() // 刷新图像
                        }

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "arrow.uturn.backward.circle")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                    }
                } else {
                    Text("Image could not be loaded.")
                        .foregroundColor(.white)
                        .onTapGesture {
                            presentationMode.wrappedValue.dismiss()
                        }
                }
            }
        }
        .onAppear {
            loadImage()
            print("View appeared, image loaded.")
        }
    }

    func loadImage() {
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fullPath = documentsDirectory.appendingPathComponent(imagePath).path
            if fileManager.fileExists(atPath: fullPath) {
                image = UIImage(contentsOfFile: fullPath)
                print("Image loaded from path: \(fullPath)")
                if let uiImage = image {
                    let aspectRatio = uiImage.size.height / uiImage.size.width
                    let orientationString = orientation.isPortrait ? "portrait" : orientation.isLandscape ? "landscape" : "unknown"
                    print("Reloaded image with width: \(uiImage.size.width), height: \(uiImage.size.height), aspect ratio: \(aspectRatio), orientation: \(orientationString)")
                }
            } else {
                print("File does not exist at path: \(fullPath)")
            }
        }
    }

    func refreshImage() {
        image = nil
        loadImage()
    }
}

struct ZoomInView_Previews: PreviewProvider {
    static var previews: some View {
        ZoomInView(imagePath: "_JOW0051")
    }
}

extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}

struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
                //print("Orientation changed to: \(UIDevice.current.orientation.rawValue)")
            }
    }
}
