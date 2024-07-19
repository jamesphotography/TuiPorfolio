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
    
    var onDelete: (() -> Void)?  // 添加这个回调函数

    init(image: Binding<UIImage?>, imageName: Binding<String>, objectName: Binding<String>, caption: Binding<String>, imagePath: Binding<String>, thumbnailPath100: Binding<String>, thumbnailPath350: Binding<String>, shouldNavigateToHome: Binding<Bool>) {
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
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Image Information")) {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                    }
                    Text("Image Name: \(imageName)")
                }

                Section(header: Text("Editable Information")) {
                    TextField("Object Name", text: $localObjectName)
                    TextField("Caption", text: $localCaption)
                }

                Section {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Text("Delete Image")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationBarTitle("Edit Image", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Save") {
                saveImage()
                presentationMode.wrappedValue.dismiss()
            })
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
        // 更新绑定的值
        objectName = localObjectName
        caption = localCaption
        
        // 实现保存操作，更新 objectName 和 caption
        SQLiteManager.shared.updatePhotoRecord(imagePath: imagePath, objectName: localObjectName, caption: localCaption)
        print("Image information updated")
    }

    private func deleteImage() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!

        let originalImageURL = documentsURL.appendingPathComponent(imagePath)
        let thumbnail350URL = documentsURL.appendingPathComponent(thumbnailPath350)
        let thumbnail100URL = documentsURL.appendingPathComponent(thumbnailPath100)

        do {
            // 删除原图
            if fileManager.fileExists(atPath: originalImageURL.path) {
                try fileManager.removeItem(at: originalImageURL)
                print("Deleted original image at: \(originalImageURL.path)")
            } else {
                print("Original image not found at: \(originalImageURL.path)")
            }

            // 删除 350 缩略图
            if fileManager.fileExists(atPath: thumbnail350URL.path) {
                try fileManager.removeItem(at: thumbnail350URL)
                print("Deleted 350 thumbnail at: \(thumbnail350URL.path)")
            } else {
                print("350 thumbnail not found at: \(thumbnail350URL.path)")
            }

            // 删除 100 缩略图
            if fileManager.fileExists(atPath: thumbnail100URL.path) {
                try fileManager.removeItem(at: thumbnail100URL)
                print("Deleted 100 thumbnail at: \(thumbnail100URL.path)")
            } else {
                print("100 thumbnail not found at: \(thumbnail100URL.path)")
            }
            // 删除数据库中的记录
            SQLiteManager.shared.deletePhotoRecord(imagePath: imagePath)
            
            print("Image deleted successfully")
            
            // 在成功删除后调用回调函数
            onDelete?()
            
            // 设置标志以触发导航
            shouldNavigateToHome = true
            print("Set shouldNavigateToHome to true")
            
            // 关闭 EditorView
            presentationMode.wrappedValue.dismiss()
            
            print("Dismissed EditorView")
        } catch {
            print("Failed to delete image: \(error.localizedDescription)")
        }


    }
}


