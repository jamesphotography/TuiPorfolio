import SwiftUI

struct NationalView: View {
    @State private var countries: [CountryData] = []
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.locale) var locale
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: NSLocalizedString("National List",comment: ""), onBackButtonTap: {
                    self.presentationMode.wrappedValue.dismiss()
                })
                .padding(.top, geometry.safeAreaInsets.top)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(countries) { country in
                            NavigationLink(destination: LocalityListView(countryName: country.englishName)) {
                                HStack {
                                    FlagView(country: country.code)
                                        .frame(width: 30, height: 20)
                                    Text(country.localizedName)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(country.totalPhotos) photos")
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
                .background(Color("BGColor"))
                
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .edgesIgnoringSafeArea(.all)
        }
        .navigationBarHidden(true)
        .onAppear {
            loadCountries()
        }
    }

    private func loadCountries() {
        let rawData = SQLiteManager.shared.getAllPhotos()
        var countryDict = [String: Int]()
        
        for photo in rawData {
            if !photo.country.isEmpty {
                countryDict[photo.country, default: 0] += 1
            }
        }
        
        let locale = Locale.current
        let languageCode: String
        let scriptCode: String
        let regionCode: String

        if #available(iOS 16, *) {
            languageCode = locale.language.languageCode?.identifier ?? "en"
            scriptCode = locale.language.script?.identifier ?? ""
            regionCode = locale.region?.identifier ?? ""
        } else {
            languageCode = locale.languageCode ?? "en"
            scriptCode = locale.scriptCode ?? ""
            regionCode = locale.regionCode ?? ""
        }

        let finalLanguageCode: String
        if languageCode == "zh" {
            if scriptCode == "Hant" || regionCode == "TW" || regionCode == "HK" || regionCode == "MO" {
                finalLanguageCode = "zh-Hant"
            } else {
                finalLanguageCode = "zh-Hans"
            }
        } else {
            finalLanguageCode = languageCode
        }
        
        countries = countryDict.compactMap { countryName, totalPhotos in
            if let code = CountryCodeManager.shared.getCountryCode(for: countryName) {
                let localizedName = CountryCodeManager.shared.getCountryName(for: code, languageCode: finalLanguageCode) ?? countryName
                return CountryData(englishName: countryName, localizedName: localizedName, code: code, totalPhotos: totalPhotos)
            } else {
                return nil
            }
        }.sorted { $0.totalPhotos > $1.totalPhotos }
    }
}

struct CountryData: Identifiable {
    let id = UUID()
    let englishName: String
    let localizedName: String
    let code: String
    let totalPhotos: Int
}

struct NationalView_Previews: PreviewProvider {
    static var previews: some View {
        NationalView()
    }
}
