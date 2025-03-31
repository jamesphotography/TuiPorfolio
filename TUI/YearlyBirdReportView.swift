import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct YearlyBirdSpecies: Identifiable {
    let id = UUID()
    let overallRank: Int
    let speciesName: String
    let firstSeenDate: Date
    let isNewSpecies: Bool
    let country: String
    let area: String
    let locality: String
    let thumbnailPath: String
}

struct YearlyBirdStats {
    var totalPhotos: Int
    var totalSpecies: Int
    var newSpeciesCount: Int
    var speciesList: [YearlyBirdSpecies]
    var countryCount: Int
    var areaCount: Int
    
    static var empty: YearlyBirdStats {
        YearlyBirdStats(
            totalPhotos: 0,
            totalSpecies: 0,
            newSpeciesCount: 0,
            speciesList: [],
            countryCount: 0,
            areaCount: 0
        )
    }
}

struct YearlyBirdReportView: View {
    @AppStorage("enableBirdWatching") private var enableBirdWatching = false
    @AppStorage("userName") private var userName: String = "James"
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date()) - 1
    @State private var yearlyStats: YearlyBirdStats = .empty
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.locale) var locale
    @State private var showingExportSheet = false
    @State private var exportedPDFURL: URL?
    
    private var availableYears: [Int] {
        let dbYears = SQLiteManager.shared.getAvailableBirdPhotoYears()
        if dbYears.isEmpty {
            let nextYear = Calendar.current.component(.year, from: Date()) + 1
            return Array((2000...nextYear).reversed())
        }
        return dbYears
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: NSLocalizedString("Annual Bird Report", comment: ""))
                    .padding(.top, geometry.safeAreaInsets.top)
                
                ScrollView {
                    VStack(spacing: 20) {
                        HStack {
                            yearSelector
                            
                            Button(action: exportReport) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(Color("TUIBLUE"))
                                    .font(.title2)
                            }
                        }
                        
                        if isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                        } else if yearlyStats.totalPhotos > 0 {
                            annualSummary
                            speciesList
                        } else {
                            Text("No bird photos in \(selectedYear)")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    .padding()
                }
                .background(Color("BGColor"))
                
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            loadYearlyStats(for: selectedYear)
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: PDFDocument(url: exportedPDFURL ?? URL(fileURLWithPath: "")),
            contentType: .pdf,
            defaultFilename: "BirdReport_\(selectedYear).pdf"
        ) { result in
            switch result {
            case .success(let url):
                print("Successfully saved PDF to \(url)")
            case .failure(let error):
                print("Error saving PDF: \(error.localizedDescription)")
            }
            
            // 清理临时文件
            if let url = exportedPDFURL {
                try? FileManager.default.removeItem(at: url)
                exportedPDFURL = nil
            }
        }
    }
    
    private var yearSelector: some View {
        Menu {
            ForEach(availableYears, id: \.self) { year in
                Button(action: {
                    selectedYear = year
                    loadYearlyStats(for: year)
                }) {
                    Text(String(year))
                        .foregroundColor(year == selectedYear ? .blue : .primary)
                }
            }
        } label: {
            HStack {
                Text("\(selectedYear)")
                    .font(.title2)
                    .fontWeight(.bold)
                Image(systemName: "chevron.down")
            }
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 2)
        }
    }
    
    private var annualSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(selectedYear)")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color("TUIBLUE"))
            + Text(", \(userName) traveled through \(yearlyStats.countryCount) countries and \(yearlyStats.areaCount) areas, capturing \(yearlyStats.totalPhotos) bird photos of \(yearlyStats.totalSpecies) different species, with \(yearlyStats.newSpeciesCount) newly discovered species!")
                .font(.headline)
                .foregroundColor(Color("TUIBLUE"))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private var speciesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Species List")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(yearlyStats.speciesList) { species in
                NavigationLink(destination: ObjectNameView(objectName: species.speciesName)) {
                    HStack(spacing: 12) {
                        if let thumbnail = loadImage(from: species.thumbnailPath) {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("No.\(species.overallRank)")
                                    .foregroundColor(.secondary)
                                    .frame(width: 50)
                                    .lineLimit(1)
                                    .fixedSize()
                                
                                Text(species.speciesName)
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                            
                            HStack {
                                Text("\(species.locality), \(species.area)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(formatDate(species.firstSeenDate))
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                        
                        if species.isNewSpecies {
                            Text("NEW")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                }
            }
        }
    }
    
    private func exportReport() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)) // A4 size
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("BirdReport_\(selectedYear).pdf")
        
        do {
            try renderer.writePDF(to: tempURL) { context in
                context.beginPage()
                
                // Title
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 24),
                    .foregroundColor: UIColor(Color("TUIBLUE"))
                ]
                let title = "\(selectedYear) Annual Bird Report"
                title.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)
                
                // Summary
                let summaryAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ]
                let summary = """
                \(userName)'s Bird Watching Report
                Total Photos: \(yearlyStats.totalPhotos)
                Total Species: \(yearlyStats.totalSpecies)
                New Species: \(yearlyStats.newSpeciesCount)
                Countries: \(yearlyStats.countryCount)
                Areas: \(yearlyStats.areaCount)
                """
                summary.draw(at: CGPoint(x: 50, y: 100), withAttributes: summaryAttributes)
                
                // Species List
                var yPosition: CGFloat = 200
                let speciesAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.black
                ]
                
                for species in yearlyStats.speciesList {
                    let speciesText = """
                    No.\(species.overallRank) \(species.speciesName)
                    Location: \(species.locality), \(species.area)
                    First Seen: \(formatDate(species.firstSeenDate))
                    \(species.isNewSpecies ? "NEW SPECIES" : "")
                    """
                    speciesText.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: speciesAttributes)
                    yPosition += 80
                    
                    if yPosition > 750 { // Start new page if near bottom
                        context.beginPage()
                        yPosition = 50
                    }
                }
            }
            
            exportedPDFURL = tempURL
            showingExportSheet = true
            
        } catch {
            print("Failed to create PDF: \(error.localizedDescription)")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if #available(iOS 16, *) {
            if locale.language.languageCode?.identifier == "zh" {
                formatter.dateFormat = "M月d日"
            } else {
                formatter.dateFormat = "MM-dd"
            }
        } else {
            if locale.languageCode == "zh" {
                formatter.dateFormat = "M月d日"
            } else {
                formatter.dateFormat = "MM-dd"
            }
        }
        return formatter.string(from: date)
    }
    
    private func loadImage(from path: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(path).path
        return UIImage(contentsOfFile: fullPath)
    }
    
    private func loadYearlyStats(for year: Int) {
        isLoading = true
        errorMessage = nil
        
        guard let stats = SQLiteManager.shared.getBirdPhotosStats(for: year) else {
            isLoading = false
            yearlyStats = .empty
            return
        }
        
        let speciesData = SQLiteManager.shared.getYearlyBirdSpecies(for: year)
        let rankings = SQLiteManager.shared.getBirdSpeciesRanking()
        
        let allPhotos = SQLiteManager.shared.getAllPhotos()
        let yearPhotos = allPhotos.filter { photo in
            let yearStr = String(year)
            return photo.dateTimeOriginal.starts(with: yearStr)
        }
        
        let countries = Set(yearPhotos.map { $0.country })
        let areas = Set(yearPhotos.map { $0.area })
        
        let speciesList = speciesData.compactMap { (name, date, isNew) -> YearlyBirdSpecies? in
            guard let rank = rankings[name],
                  let firstPhoto = yearPhotos.first(where: { $0.objectName == name }) else { return nil }
            
            let latestPhoto = yearPhotos
                .filter { $0.objectName == name }
                .max { $0.dateTimeOriginal < $1.dateTimeOriginal }
            
            return YearlyBirdSpecies(
                overallRank: rank,
                speciesName: name,
                firstSeenDate: date,
                isNewSpecies: isNew,
                country: firstPhoto.country,
                area: firstPhoto.area,
                locality: firstPhoto.locality,
                thumbnailPath: latestPhoto?.thumbnailPath100 ?? firstPhoto.thumbnailPath100
            )
        }
        
        yearlyStats = YearlyBirdStats(
            totalPhotos: stats.totalPhotos,
            totalSpecies: stats.speciesCount,
            newSpeciesCount: speciesList.filter { $0.isNewSpecies }.count,
            speciesList: speciesList,
            countryCount: countries.count,
            areaCount: areas.count
        )
        
        isLoading = false
    }
}

// PDF Document Wrapper
struct PDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    init(configuration: ReadConfiguration) throws {
        url = URL(fileURLWithPath: "")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url)
    }
}

#Preview {
    YearlyBirdReportView()
}
