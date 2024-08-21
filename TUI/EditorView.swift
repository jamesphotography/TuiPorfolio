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
    @State private var localObjectName: String
    @State private var localCaption: String
    @State private var localRating: Int
    @State private var latitude: String
    @State private var longitude: String
    @State private var locationInfo: String = ""
    
    @State private var showLocationLookupAlert = false
    @State private var locationLookupMessage = ""
    @State private var isPerformingLookup = false
    
    init(image: Binding<UIImage?>, imageName: Binding<String>, objectName: Binding<String>, caption: Binding<String>, imagePath: Binding<String>, thumbnailPath100: Binding<String>, thumbnailPath350: Binding<String>, shouldNavigateToHome: Binding<Bool>, initialRating: Int, initialLatitude: Double, initialLongitude: Double, initialCountry: String, initialArea: String, initialLocality: String) {
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
        self._locationInfo = State(initialValue: "\(initialCountry), \(initialArea), \(initialLocality)")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Image")) {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                Section(header: Text("Edit Details")) {
                    HStack {
                        Text("Rating")
                        Spacer()
                        EditableStarRating(rating: $localRating)
                    }
                    EditableField(title: "Title", text: $localObjectName)
                    EditableTextEditor(title: "Caption", text: $localCaption)
                }
                
                Section(header: Text("GPS Information")) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 10) {
                            EditableField(title: "Lat:", text: $latitude, keyboardType: .numbersAndPunctuation)
                            EditableField(title: "Lon:", text: $longitude, keyboardType: .numbersAndPunctuation)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button(action: lookupLocation) {
                            if isPerformingLookup {
                                ProgressView()
                            } else {
                                Image(systemName: "location.fill.viewfinder")
                                    .foregroundColor(.red)
                                    .shadow(radius: 2)
                                    .font(.title)
                            }
                        }
                        .frame(width: 44, height: 80)
                        .disabled(isPerformingLookup)
                    }
                    HStack{
                        Spacer()
                        Text(locationInfo)
                            .font(.subheadline)
                        Spacer()
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
                    .font(.headline)
                    .onTapGesture {
                        rating = index
                    }
            }
        }
    }
}

struct EditableField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)
            TextField("", text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .background(Color(.systemGray6))
                .cornerRadius(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.gray, lineWidth: 1)
                )
        }
    }
}

struct EditableTextEditor: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            TextEditor(text: $text)
                .frame(height: 100)
                .background(Color(.systemGray6))
                .cornerRadius(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.gray, lineWidth: 1)
                )
        }
    }
}

struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView(
            image: .constant(UIImage(systemName: "photo")),
            imageName: .constant("Sample Image"),
            objectName: .constant("Sample Object"),
            caption: .constant("Sample Caption"),
            imagePath: .constant("/path/to/image"),
            thumbnailPath100: .constant("/path/to/thumbnail100"),
            thumbnailPath350: .constant("/path/to/thumbnail350"),
            shouldNavigateToHome: .constant(false),
            initialRating: 3,
            initialLatitude: 40.7128,
            initialLongitude: -74.0060,
            initialCountry: "United States",
            initialArea: "New York",
            initialLocality: "New York City"
        )
    }
}
