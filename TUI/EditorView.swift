import SwiftUI
import CoreLocation

struct EditorView: View {
    @Binding var image: UIImage?
    @Binding var imageName: String
    @Binding var objectName: String
    @Binding var caption: String
    @Binding var imagePath: String
    @Binding var thumbnailPath100: String
    @Binding var thumbnailPath350: String
    @Binding var shouldNavigateToHome: Bool
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteConfirmation = false
    @State private var localObjectName: String
    @State private var localCaption: String
    @State private var localRating: Int
    @State private var latitude: String
    @State private var longitude: String
    @State private var locationInfo: String = ""
    
    @State private var showLocationLookupAlert = false
    @State private var locationLookupMessage = ""
    @State private var isPerformingLookup = false
    
    var onDelete: (() -> Void)?
    
    init(image: Binding<UIImage?>, imageName: Binding<String>, objectName: Binding<String>, caption: Binding<String>, imagePath: Binding<String>, thumbnailPath100: Binding<String>, thumbnailPath350: Binding<String>, shouldNavigateToHome: Binding<Bool>, initialRating: Int, initialLatitude: Double, initialLongitude: Double) {
        self._image = image
        self._imageName = imageName
        self._objectName = objectName
        self._caption = caption
        self._imagePath = imagePath
        self._thumbnailPath100 = thumbnailPath100
        self._thumbnailPath350 = thumbnailPath350
        self._shouldNavigateToHome = shouldNavigateToHome
        self._localObjectName = State(initialValue: objectName.wrappedValue)
        self._localCaption = State(initialValue: caption.wrappedValue)
        self._localRating = State(initialValue: initialRating)
        self._latitude = State(initialValue: String(initialLatitude))
        self._longitude = State(initialValue: String(initialLongitude))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Image")) {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                Section(header: Text("Edit Details")) {
                    HStack {
                        Text("Rating")
                        Spacer()
                        EditableStarRating(rating: $localRating)
                    }
                    TextField("Object Name", text: $localObjectName)
                    TextEditor(text: $localCaption)
                        .frame(height: 150)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Section(header: Text("GPS Information")) {
                    HStack(alignment: .top) {
                        VStack {
                            HStack {
                                Text("Lat:")
                                    .font(.caption)
                                    .frame(width: 35, alignment: .leading)
                                TextField("Latitude", text: $latitude)
                                    .keyboardType(.numbersAndPunctuation)
                            }
                            HStack {
                                Text("Lon:")
                                    .font(.caption)
                                    .frame(width: 35, alignment: .leading)
                                TextField("Longitude", text: $longitude)
                                    .keyboardType(.numbersAndPunctuation)
                            }
                        }
                        Button(action: lookupLocation) {
                            if isPerformingLookup {
                                ProgressView()
                            } else {
                                Image(systemName: "location.fill.viewfinder")
                                    .foregroundColor(Color("TUIBLUE"))
                                    .font(.title)
                            }
                        }
                        .frame(height: 80)  // Adjust this value to match the height of two text fields
                        .disabled(isPerformingLookup)
                    }
                    
                    Text(locationInfo)
                        .font(.caption)
                }
                
                Section {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Image")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationBarTitle("Edit Image", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveImage()
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Confirm Delete"),
                    message: Text("Are you sure you want to delete this image?"),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteImage()
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(isPresented: $showLocationLookupAlert) {
                Alert(
                    title: Text("Location Lookup"),
                    message: Text(locationLookupMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func saveImage() {
        objectName = localObjectName
        caption = localCaption
        let newLatitude = Double(latitude) ?? 0.0
        let newLongitude = Double(longitude) ?? 0.0
        SQLiteManager.shared.updatePhotoRecord(
            imagePath: imagePath,
            objectName: localObjectName,
            caption: localCaption,
            starRating: localRating,
            latitude: newLatitude,
            longitude: newLongitude,
            country: extractLocationComponent(.country),
            area: extractLocationComponent(.area),
            locality: extractLocationComponent(.locality)
        )
    }
    
    private func deleteImage() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let imagePaths = [imagePath, thumbnailPath350, thumbnailPath100]
        
        for path in imagePaths {
            let fileURL = documentsURL.appendingPathComponent(path)
            try? fileManager.removeItem(at: fileURL)
        }
        
        SQLiteManager.shared.deletePhotoRecord(imagePath: imagePath)
        
        onDelete?()
        shouldNavigateToHome = true
        presentationMode.wrappedValue.dismiss()
    }
    
    private func lookupLocation() {
        guard let lat = Double(latitude), let lon = Double(longitude) else {
            locationLookupMessage = "Please enter valid latitude and longitude."
            showLocationLookupAlert = true
            return
        }
        
        isPerformingLookup = true
        let location = CLLocation(latitude: lat, longitude: lon)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "en_US")) { placemarks, error in
            isPerformingLookup = false
            if let error = error {
                locationLookupMessage = "Error looking up location: \(error.localizedDescription)"
                showLocationLookupAlert = true
                return
            }
            
            if let placemark = placemarks?.first {
                let country = placemark.country ?? "Unknown Country"
                let area = placemark.administrativeArea ?? "Unknown Area"
                let locality = placemark.locality ?? "Unknown Locality"
                
                locationInfo = "\(country), \(area), \(locality)"
            } else {
                locationInfo = "No location information found"
            }
        }
    }
    
    private func extractLocationComponent(_ component: LocationComponent) -> String {
        let components = locationInfo.components(separatedBy: ", ")
        switch component {
        case .country:
            return components.first ?? "Unknown Country"
        case .area:
            return components.count > 1 ? components[1] : "Unknown Area"
        case .locality:
            return components.last ?? "Unknown Locality"
        }
    }
}

enum LocationComponent {
    case country, area, locality
}

struct EditableStarRating: View {
    @Binding var rating: Int
    
    var body: some View {
        HStack {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundColor(index <= rating ? .yellow : .gray)
                    .onTapGesture {
                        rating = index
                    }
            }
        }
    }
}
