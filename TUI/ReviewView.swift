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
    @Binding var focalLength: Double
    @Binding var fNumber: Double
    @Binding var exposureTime: Double
    @Binding var isoSpeedRatings: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            //VStack(alignment: .leading, spacing: 4) {
            // 显示星等
            HStack {
                Spacer()
                ForEach(0..<5) { index in
                    Image(systemName: index < starRating ? "star.fill" : "star")
                        .foregroundColor(.orange)
                        .font(.subheadline)
                }
                Spacer()
            }
            Spacer()
            VStack(alignment: .leading,spacing: 10) {
                Text("Object Name: \(objectName)")
                Text("Capture Date: \(captureDate)")
                Text("Camera: \(cameraInfo)")
                Text("Lens: \(lensInfo)")
                Text("Exposure: \(String(format: "%.1f", focalLength)) mm f/\(String(format: "%.1f", fNumber)) 1/\(String(format: "%.0f", 1/exposureTime)) s ISO: \(isoSpeedRatings)")
                Text("Location: \(locality), \(area), \(country) ")
                Text("Caption: \(caption)")
            }
            .font(.subheadline)

        }
        .padding(10)
        .background(Color("Pulse"))
        .cornerRadius(10)
    }
}
