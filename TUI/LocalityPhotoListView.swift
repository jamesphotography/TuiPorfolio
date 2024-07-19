import SwiftUI
import MapKit

struct LocalityPhotoListView: View {
    var locality: String
    @State private var photos: [Photo] = []
    @State private var displayedPhotos: [Photo] = []
    @State private var currentPage = 0
    @State private var hasMorePhotos = true
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
    private let itemsPerPage = 30
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Headbar
                HeadBarView(title: locality)
                    .padding(.top, geometry.safeAreaInsets.top)

                // Map View
                LocalityMapView(region: $region, photos: photos)
                    .frame(height: 200)
                    .padding(.horizontal)

                // Main content
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Array(displayedPhotos.enumerated()), id: \.element.id) { index, photo in
                            NavigationLink(destination: DetailView(photos: photos, initialIndex: photos.firstIndex(where: { $0.id == photo.id }) ?? 0, onDismiss: { _ in })) {
                                PhotoThumbnailView(photo: photo, size: (UIScreen.main.bounds.width - 60) / 3)
                            }
                        }
                    }
                    .padding()
                    
                    if hasMorePhotos {
                        Button(action: loadMorePhotos) {
                            Text("Load more ...")
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                                .padding(8)
                                .frame(maxWidth: UIScreen.main.bounds.width / 2)
                                .background(Color.black)
                                .cornerRadius(15)
                        }
                        .padding(.vertical)
                    } else if !photos.isEmpty {
                        Text("No More Photos")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                            .padding(8)
                    }
                }

                // Bottombar
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadInitialPhotos)
    }

    private func loadInitialPhotos() {
        photos = SQLiteManager.shared.getAllPhotos().filter { $0.locality == locality }
        loadMorePhotos()
        
        if let firstPhoto = photos.first {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: firstPhoto.latitude, longitude: firstPhoto.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
    }

    private func loadMorePhotos() {
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, photos.count)
        
        if startIndex < endIndex {
            let newPhotos = Array(photos[startIndex..<endIndex])
            displayedPhotos.append(contentsOf: newPhotos)
            currentPage += 1
            hasMorePhotos = endIndex < photos.count
        } else {
            hasMorePhotos = false
        }
    }
}

struct LocationWrapper: Hashable {
    let coordinate: CLLocationCoordinate2D
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
    
    static func == (lhs: LocationWrapper, rhs: LocationWrapper) -> Bool {
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

struct LocalityMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var photos: [Photo]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(region, animated: true)
        
        // Remove existing annotations
        uiView.removeAnnotations(uiView.annotations)
        
        // Add new annotations for unique locations
        let uniqueLocations = Set(photos.map { LocationWrapper(coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) })
        for location in uniqueLocations {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location.coordinate
            uiView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocalityMapView

        init(_ parent: LocalityMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "PhotoPin"
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            
            // Customize the pin
            annotationView?.markerTintColor = .blue
            
            // Make the pin smaller
            annotationView?.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            
            return annotationView
        }
    }
}

struct LocalityPhotoListView_Previews: PreviewProvider {
    static var previews: some View {
        LocalityPhotoListView(locality: "Adelaide")
    }
}
