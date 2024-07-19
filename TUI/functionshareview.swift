import SwiftUI

// MARK: - Photo Thumbnail View

func PhotoThumbnailView(photo: Photo, size: CGFloat) -> some View {
    Group {
        if let uiImage = loadImage(from: photo.thumbnailPath100) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
                .cornerRadius(5)
                .shadow(radius: 3)
        } else {
            Color.gray
                .frame(width: size, height: size)
                .cornerRadius(5)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.white)
                )
        }
    }
}

// MARK: - Helper Functions

func loadImage(from relativePath: String) -> UIImage? {
    let fileManager = FileManager.default
    if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fullPath = documentsDirectory.appendingPathComponent(relativePath).path
        if fileManager.fileExists(atPath: fullPath) {
            return UIImage(contentsOfFile: fullPath)
        }
    }
    return nil
}
