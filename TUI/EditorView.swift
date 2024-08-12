import SwiftUI

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
    
    var onDelete: (() -> Void)?
    
    init(image: Binding<UIImage?>, imageName: Binding<String>, objectName: Binding<String>, caption: Binding<String>, imagePath: Binding<String>, thumbnailPath100: Binding<String>, thumbnailPath350: Binding<String>, shouldNavigateToHome: Binding<Bool>, initialRating: Int) {
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
        }
    }
    
    private func saveImage() {
        objectName = localObjectName
        caption = localCaption
        SQLiteManager.shared.updatePhotoRecord(imagePath: imagePath, objectName: localObjectName, caption: localCaption, starRating: localRating)
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
