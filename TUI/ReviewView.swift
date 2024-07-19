import SwiftUI

struct ReviewView: View {
    @Binding var cameraInfo: String
    @Binding var lensInfo: String
    @Binding var captureDate: String
    @Binding var country: String
    @Binding var area: String
    @Binding var locality: String
    @Binding var starRating: Int
    @Binding var objectName: String
    @Binding var caption: String

    var body: some View {
        VStack {
            Text("Camera: \(cameraInfo)")
                .font(.caption2)
            Text("Lens: \(lensInfo)")
                .font(.caption2)
            Text("Capture Date: \(captureDate)")
                .font(.caption2)
            Text("Country: \(country)")
                .font(.caption)
            Text("Area: \(area)")
                .font(.caption)
            Text("Locality: \(locality)")
                .font(.caption)
            Text("Object Name: \(objectName)")
                .font(.caption)
            Text("Caption: \(caption)")
                .font(.caption)
            // 显示星等
            HStack {
                ForEach(0..<5) { index in
                    Image(systemName: index < starRating ? "star.fill" : "star")
                        .foregroundColor(.orange)
                        .font(.caption2)
                }
            }
        }
    }
}
