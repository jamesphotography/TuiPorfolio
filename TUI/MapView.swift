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
                        Annotation("Photo Location", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
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
                                } else {
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .foregroundColor(.gray)
                                }
                                
                                Text(formatCoordinates(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
                                    .font(.caption)
                                    .padding(5)
                                    .background(Color.white)
                                    .cornerRadius(5)
                                    .shadow(radius: 5)
                                    .onTapGesture {
                                        let coordinates = "\(latitude), \(longitude)"
                                        copyToClipboard(text: coordinates)
                                        showCopiedAlert = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            showCopiedAlert = false
                                        }
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
    
    private func copyToClipboard(text: String) {
        UIPasteboard.general.string = text
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

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(
            latitude: -34.9285,
            longitude: 138.6007,
            country: "Australia",
            locality: "Adelaide",
            thumbnailPath: "",
            showMap: .constant(true)
        )
    }
}
