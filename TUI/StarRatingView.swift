import SwiftUI

struct StarRatingView: View {
    var rating: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                if index < Int(rating) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                } else if index < Int(ceil(rating)) {
                    Image(systemName: "star.leadinghalf.fill")
                        .foregroundColor(.yellow)
                } else {
                    Image(systemName: "star")
                        .foregroundColor(.gray)
                }
            }
        }
        .font(.system(size: 10))
    }
}

struct StarRatingView_Previews: PreviewProvider {
    static var previews: some View {
        StarRatingView(rating: 3.5)
    }
}
