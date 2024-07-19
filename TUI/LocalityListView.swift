import SwiftUI

struct LocalityListView: View {
    let countryName: String
    @State private var localities: [LocalityData] = []
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Headbar
                HeadBarView(
                    title: countryName,
                    countryCode: CountryCodeManager.shared.getCountryCode(for: countryName),
                    onBackButtonTap: {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                )
                .padding(.top, geometry.safeAreaInsets.top)
                // 主要內容
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(localities) { locality in
                            NavigationLink(destination: LocalityPhotoListView(locality: locality.name)) {
                                HStack {
                                    Text(locality.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(locality.totalPhotos)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                }

                // 底部導航欄
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .edgesIgnoringSafeArea(.all)
        }
        .navigationBarHidden(true)
        .onAppear {
            loadLocalities()
        }
    }

    private func loadLocalities() {
        let rawData = SQLiteManager.shared.getAllPhotos()
        var localityDict = [String: Int]()
        
        for photo in rawData {
            if photo.country == countryName && !photo.locality.isEmpty {
                localityDict[photo.locality, default: 0] += 1
            }
        }
        
        localities = localityDict.map { LocalityData(name: $0.key, totalPhotos: $0.value) }
            .sorted { $0.totalPhotos > $1.totalPhotos }
    }
}

struct LocalityData: Identifiable {
    let id = UUID()
    let name: String
    let totalPhotos: Int
}
