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
    @State private var country: String = ""
    @State private var area: String = ""
    @State private var locality: String = ""
    
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
        self._country = State(initialValue: initialCountry)
        self._area = State(initialValue: initialArea)
        self._locality = State(initialValue: initialLocality)
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
                        Text("\(country), \(area), \(locality)")
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
            country: country,
            area: area,
            locality: locality
        )
        SQLiteManager.shared.invalidateCache()
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
            DispatchQueue.main.async {
                isPerformingLookup = false
                
                if let error = error {
                    locationLookupMessage = "Error looking up location: \(error.localizedDescription)"
                    showLocationLookupAlert = true
                    return
                }
                
                if let placemark = placemarks?.first {
                    // 国家信息处理
                    country = placemark.country ?? "Unknown Country"
                    
                    // 区域信息的降级处理
                    let possibleAreas = [
                        placemark.administrativeArea,
                        placemark.subAdministrativeArea,
                        placemark.locality,
                        placemark.subLocality,
                        placemark.inlandWater,
                        placemark.ocean,
                        placemark.country // 添加国家作为area的备选项
                    ].compactMap { $0 }
                    
                    area = possibleAreas.first ?? country // 如果没有其他选项，使用国家名称
                    
                    // 地点信息的降级处理
                    let areasOfInterest = placemark.areasOfInterest ?? []
                    let possibleLocalities = [
                        placemark.locality,
                        placemark.subLocality,
                        placemark.name
                    ].compactMap { $0 }
                    
                    // 优先使用areasOfInterest中除国家名称外的第一个地点
                    let filteredAreasOfInterest = areasOfInterest.filter { $0 != country }
                    if let firstArea = filteredAreasOfInterest.first {
                        locality = firstArea
                    } else {
                        locality = possibleLocalities.first ?? "Unknown Location"
                    }
                    
                    locationInfo = "\(country), \(area), \(locality)"
                    
#if DEBUG
                    print("Location Debug Info:")
                    print("Country: \(country)")
                    print("Area: \(area)")
                    print("Locality: \(locality)")
                    print("Raw Placemark Data:")
                    print("- Administrative Area: \(placemark.administrativeArea ?? "nil")")
                    print("- Sub-Administrative Area: \(placemark.subAdministrativeArea ?? "nil")")
                    print("- Locality: \(placemark.locality ?? "nil")")
                    print("- Sub-Locality: \(placemark.subLocality ?? "nil")")
                    print("- Inland Water: \(placemark.inlandWater ?? "nil")")
                    print("- Ocean: \(placemark.ocean ?? "nil")")
                    print("- Areas of Interest: \(placemark.areasOfInterest ?? [])")
#endif
                    
                } else {
                    locationLookupMessage = "No location information found"
                    showLocationLookupAlert = true
                }
            }
        }
    }
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
