import SwiftUI

struct LensCountView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var lensCounts: [(String, Int, String)] = [] // (镜头型号, 照片数量, 最早时间)
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sortOption: SortOption = .lastUsed
    @State private var sortOrder: SortOrder = .descending
    @State private var showingSortOptions = false

    enum SortOption: String, CaseIterable {
        case lastUsed = "Last Used"
        case photoCount = "Photo Count"
    }

    enum SortOrder: String, CaseIterable {
        case ascending = "Ascending"
        case descending = "Descending"
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // HeadBarView
                HeadBarView(title: NSLocalizedString("Lens Count", comment: ""))
                    .padding(.top, geometry.safeAreaInsets.top)

                // Main content area
                ScrollView {
                    VStack(spacing: 8) {
                        if isLoading {
                            ProgressView("Loading...")
                                .padding()
                        } else if let error = errorMessage {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                        } else if lensCounts.isEmpty {
                            Text("No lens records found")
                                .padding()
                        } else {
                            HStack {
                                Text("Found \(lensCounts.count) lens models")
                                    .font(.caption2)
                                Spacer()
                                Button(action: {
                                    showingSortOptions = true
                                }) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .foregroundColor(Color("TUIBLUE"))
                                        .font(.caption)
                                }
                                .actionSheet(isPresented: $showingSortOptions) {
                                    ActionSheet(
                                        title: Text("Sort Options"),
                                        buttons: [
                                            .default(Text("Last Used (\(sortOrder == .ascending ? "↑" : "↓"))")) {
                                                sortOption = .lastUsed
                                                sortLensCounts()
                                            },
                                            .default(Text("Photo Count (\(sortOrder == .ascending ? "↑" : "↓"))")) {
                                                sortOption = .photoCount
                                                sortLensCounts()
                                            },
                                            .default(Text(sortOrder == .ascending ? "Sort Descending" : "Sort Ascending")) {
                                                sortOrder = sortOrder == .ascending ? .descending : .ascending
                                                sortLensCounts()
                                            },
                                            .cancel()
                                        ]
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            ForEach(Array(lensCounts.enumerated()), id: \.element.0) { index, lensData in
                                let (model, count, earliestTime) = lensData
                                NavigationLink(destination: LensDetailView(lensModel: model)) {
                                    HStack(spacing: 10) {
                                        Text("No. \(index + 1)")
                                            .foregroundColor(.secondary)
                                            .frame(width: 50, alignment: .leading)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(model)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Text("Last used: \(formatDate(earliestTime))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(count)")
                                            .foregroundColor(.secondary)
                                            .frame(minWidth: 30, alignment: .trailing)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .background(Color("BGColor"))

                // Bottom navigation bar
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadLensCounts)
    }

    private func loadLensCounts() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .background).async {
            let lensInfo = SQLiteManager.shared.getLensInfo()
            
            DispatchQueue.main.async {
                self.lensCounts = lensInfo
                self.sortLensCounts()
                self.isLoading = false
                if lensInfo.isEmpty {
                    self.errorMessage = "No lens data found"
                }
            }
        }
    }
    
    private func sortLensCounts() {
        switch sortOption {
        case .lastUsed:
            lensCounts.sort { lhs, rhs in
                let lhsDate = dateFromString(lhs.2)
                let rhsDate = dateFromString(rhs.2)
                return sortOrder == .ascending ? lhsDate < rhsDate : lhsDate > rhsDate
            }
        case .photoCount:
            lensCounts.sort { lhs, rhs in
                sortOrder == .ascending ? lhs.1 < rhs.1 : lhs.1 > rhs.1
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if let date = dateFormatter.date(from: dateString) {
            dateFormatter.dateFormat = "MMM d, yyyy"
            return dateFormatter.string(from: date)
        }
        
        return dateString
    }
    
    private func dateFromString(_ dateString: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.date(from: dateString) ?? Date.distantPast
    }
}

struct LensCountView_Previews: PreviewProvider {
    static var previews: some View {
        LensCountView()
    }
}
