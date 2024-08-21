import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    let latitude: Double
    let longitude: Double
    let country: String
    let locality: String
    let thumbnailPath: String
   
    @State private var position: MapCameraPosition
    @State private var showCopiedAlert = false
    @State private var showingActionSheet = false

    init(latitude: Double, longitude: Double, country: String, locality: String, thumbnailPath: String, showMap: Binding<Bool>) {
        self.latitude = latitude
        self.longitude = longitude
        self.country = country
        self.locality = locality
        self.thumbnailPath = thumbnailPath
            
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )))
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Headbar
                HeadBarView(title: "\(locality), \(country)")
                    .padding(.top, geometry.safeAreaInsets.top)

                // Main
                VStack {
                    Map(position: $position) {
                        Annotation(NSLocalizedString("Tap for navigation options", comment: ""), coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
                            VStack {
                                let fullPath = getFullPath(for: thumbnailPath)
                                if let uiImage = UIImage(contentsOfFile: fullPath) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        .shadow(radius: 3)
                                        .onTapGesture {
                                            showingActionSheet = true
                                        }
                                } else {
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .foregroundColor(.gray)
                                        .onTapGesture {
                                            showingActionSheet = true
                                        }
                                }
                                
                                Button(action: {
                                    showingActionSheet = true
                                }) {
                                    Text(formatCoordinates(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
                                        .font(.caption)
                                        .padding(5)
                                        .background(Color.white)
                                        .cornerRadius(5)
                                        .shadow(radius: 5)
                                }
                                
                                Image(systemName: "mappin")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    
                    Spacer()
                }
                .background(Color("BGColor"))

                // Bottombar
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
            .maptoast(isPresenting: $showCopiedAlert, text: Text("Coordinates copied"))
            .confirmationDialog("Navigation Options", isPresented: $showingActionSheet) {
                Button("Apple Maps") {
                    openMapsNavigation(using: .apple)
                }
                Button("Google Maps") {
                    openMapsNavigation(using: .google)
                }
                Button("Copy GPS Data") {
                    copyGPSData()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
    
    private func formatCoordinates(_ coordinate: CLLocationCoordinate2D) -> String {
        let latitudeString = String(format: "%.2f", abs(coordinate.latitude))
        let longitudeString = String(format: "%.2f", abs(coordinate.longitude))
        let latitudeDirection = coordinate.latitude >= 0 ? "N" : "S"
        let longitudeDirection = coordinate.longitude >= 0 ? "E" : "W"
        return "\(latitudeString)° \(latitudeDirection), \(longitudeString)° \(longitudeDirection)"
    }
    
    private func copyGPSData() {
        let coordinates = "\(latitude), \(longitude)"
        UIPasteboard.general.string = coordinates
        showCopiedAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopiedAlert = false
        }
    }
    
    private func getFullPath(for relativePath: String) -> String {
        if let path = Bundle.main.path(forResource: relativePath, ofType: nil) {
            return path
        } else {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fullPath = documentsDirectory.appendingPathComponent(relativePath).path
            return fullPath
        }
    }
    
    private func openMapsNavigation(using mapType: MapType) {
        var urlString: String
        
        switch mapType {
        case .apple:
            urlString = "maps://?daddr=\(latitude),\(longitude)"
        case .google:
            urlString = "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving"
        }
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            print("Cannot open URL")
            // 如果无法打开URL，您可以在这里添加fallback选项，比如打开App Store下载相应的应用
        }
    }
    
    enum MapType {
        case apple, google
    }
}

extension View {
    func maptoast(isPresenting: Binding<Bool>, text: Text) -> some View {
        ZStack {
            self
            if isPresenting.wrappedValue {
                VStack {
                    Spacer()
                    text
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 100)
                }
                .transition(.opacity)
                .animation(.easeInOut, value: isPresenting.wrappedValue)
            }
        }
    }
}
