import SwiftUI

struct NationalView: View {
    @State private var countries: [CountryData] = []
    @State private var birdList: [[String]] = []
    @AppStorage("enableBirdWatching") private var enableBirdWatching = false
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.locale) var locale
    @State private var needsRefresh: Bool = false
    @State private var executionTime: TimeInterval = 0  // New state for execution time
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: NSLocalizedString("National List", comment: ""), onBackButtonTap: {
                    self.presentationMode.wrappedValue.dismiss()
                })
                .padding(.top, geometry.safeAreaInsets.top)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(countries) { country in
                            NavigationLink(destination: LocalityListView(countryName: country.englishName)) {
                                HStack {
                                    FlagView(country: country.code)
                                        .frame(width: 30, height: 30)
                                    Text(country.localizedName)
                                        .font(.title2)
                                    Spacer()
                                    if enableBirdWatching && country.birdSpeciesCount > 0 {
                                        Text("\(country.birdSpeciesCount) birds")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                    Text("\(country.totalPhotos) photos")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Image(systemName: "chevron.right")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(5)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color("BGColor"))
                
                if !countries.isEmpty {
                    Text("Execution Time: \(String(format: "%.3f", executionTime))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                }
                
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .edgesIgnoringSafeArea(.all)
        }
        .navigationBarHidden(true)
        .onAppear {
            loadBirdList()
            loadCountries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .birdWatchingStatusChanged)) { _ in
            loadCountries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newPhotosAdded)) { _ in
            NationalViewCache.shared.clear()
            loadCountries()
        }
        .onChange(of: needsRefresh) { _, newValue in
            if newValue {
                loadCountries()
                needsRefresh = false
            }
        }
    }

    private func loadBirdList() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            guard let url = Bundle.main.url(forResource: "birdInfo", withExtension: "json") else {
                print("Error: birdInfo.json file not found")
                return
            }
            let data = try Data(contentsOf: url)
            birdList = try JSONDecoder().decode([[String]].self, from: data)
        } catch {
            print("Error loading bird list: \(error.localizedDescription)")
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        print("loadBirdList execution time: \(executionTime) seconds")
    }

    private func isBird(_ objectName: String) -> Bool {
        return birdList.contains { birdNames in
            birdNames.contains(objectName)
        }
    }

    private func loadCountries() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        if let cachedCountries = NationalViewCache.shared.countries, !NationalViewCache.shared.shouldUpdate() {
            self.countries = cachedCountries
            let endTime = CFAbsoluteTimeGetCurrent()
            self.executionTime = endTime - startTime
            print("loadCountries (cached) execution time: \(executionTime) seconds")
            return
        }
        
        let rawData = SQLiteManager.shared.getAllPhotos()
        var countryDict = [String: (photoCount: Int, birdSpecies: Set<String>)]()
        
        for photo in rawData {
            if !photo.country.isEmpty {
                var currentData = countryDict[photo.country] ?? (photoCount: 0, birdSpecies: Set<String>())
                currentData.photoCount += 1
                if !photo.objectName.isEmpty && isBird(photo.objectName) {
                    currentData.birdSpecies.insert(photo.objectName)
                }
                countryDict[photo.country] = currentData
            }
        }
        
        let locale = Locale.current
        let finalLanguageCode = determineFinalLanguageCode(locale)
        
        countries = countryDict.compactMap { countryName, data in
            if let code = CountryCodeManager.shared.getCountryCode(for: countryName) {
                let localizedName = CountryCodeManager.shared.getCountryName(for: code, languageCode: finalLanguageCode) ?? countryName
                return CountryData(
                    englishName: countryName,
                    localizedName: localizedName,
                    code: code,
                    totalPhotos: data.photoCount,
                    birdSpeciesCount: data.birdSpecies.count
                )
            } else {
                return nil
            }
        }.sorted { $0.totalPhotos > $1.totalPhotos }
        
        NationalViewCache.shared.update(with: countries)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        self.executionTime = endTime - startTime
        print("loadCountries execution time: \(executionTime) seconds")
    }
    
    private func determineFinalLanguageCode(_ locale: Locale) -> String {
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

        if languageCode == "zh" {
            if scriptCode == "Hant" || regionCode == "TW" || regionCode == "HK" || regionCode == "MO" {
                return "zh-Hant"
            } else {
                return "zh-Hans"
            }
        } else {
            return languageCode
        }
    }
}

struct CountryData: Identifiable, Equatable {
    let id = UUID()
    let englishName: String
    let localizedName: String
    let code: String
    let totalPhotos: Int
    let birdSpeciesCount: Int
}

extension Notification.Name {
    static let newPhotosAdded = Notification.Name("com.yourapp.newPhotosAdded")
    static let birdWatchingStatusChanged = Notification.Name("com.yourapp.birdWatchingStatusChanged")
}
