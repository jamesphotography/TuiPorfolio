import SwiftUI

struct SearchView: View {
    @State private var searchText: String = ""
    @State private var searchResults: [Photo] = []
    @State private var showSearchResults = false
    @State private var totalResults: Int = 0
    @State private var hotSearches: [String] = HotSearchManager.shared.getHotSearches()
    @State private var currentPage = 0
    @State private var sortOrder: SortOrder = .descending
    let itemsPerPage = 100

    enum SortOrder {
        case ascending, descending
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Headbar
                HeadBarView(title: NSLocalizedString("Search", comment: ""))
                    .padding(.top, geometry.safeAreaInsets.top)

                Spacer()

                // Main
                VStack(spacing: 8) {
                    // 搜索框
                    searchBar

                    if showSearchResults {
                        HStack {
                            // 搜索结果数量
                            Text("Found \(totalResults) photos")
                                .font(.headline)
                                .padding(.leading, 8)
                            
                            Spacer()
                            
                            // 排序按钮
                            sortingButton
                        }
                    }

                    // 热门搜索项或搜索结果
                    if !showSearchResults {
                        hotSearchesView
                    } else {
                        // 使用 PhotoListView 显示搜索结果
                        PhotoListView(photos: searchResults, loadMoreAction: loadMore, canLoadMore: searchResults.count < totalResults)
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .background(Color("BGColor"))

                Spacer()

                // Bottombar
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    private var searchBar: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundColor(Color("TUIBLUE"))
                    .padding(.leading, 8)
                TextField("Search", text: $searchText, onCommit: performSearch)
                    .font(.caption)
            }
            .padding(8)
            .background(Color.white)
            .cornerRadius(8.0)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("TUIBLUE"), lineWidth: 1)
            )
            
            Button(action: {
                searchText = ""
                showSearchResults = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .padding([.leading, .trailing], 16)
    }

    private var sortingButton: some View {
        Button(action: {
            sortOrder = sortOrder == .ascending ? .descending : .ascending
            sortSearchResults()
        }) {
            HStack {
                Text("Sort by time")
                Image(systemName: sortOrder == .ascending ? "arrow.up.square" : "arrow.down.square")
            }
            .foregroundColor(Color("TUIBLUE"))
            .font(.subheadline)
        }
        .padding(.horizontal)
    }

    private var hotSearchesView: some View {
        VStack(alignment: .leading) {
            Text("Popular Searches")
                .font(.body)
                .padding(.leading)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                ForEach(hotSearches, id: \.self) { item in
                    Button(action: {
                        searchText = item
                        performSearch()
                    }) {
                        Text(item)
                            .padding(8)
                            .background(Color(.systemGray5))
                            .cornerRadius(3)
                            .font(.caption)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color("TUIBLUE"), lineWidth: 1)
                            )
                    }
                }
            }
            .padding()
        }
    }

    private func performSearch() {
        totalResults = SQLiteManager.shared.countPhotos(keyword: searchText)
        searchResults = SQLiteManager.shared.searchPhotos(keyword: searchText, limit: itemsPerPage, offset: 0)
        currentPage = 0
        showSearchResults = true
        sortSearchResults()

        // 更新热门搜索关键字
        HotSearchManager.shared.addHotSearch(searchText)
        hotSearches = HotSearchManager.shared.getHotSearches()

        // 隐藏键盘
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func loadMore() {
        currentPage += 1
        let moreResults = SQLiteManager.shared.searchPhotos(keyword: searchText, limit: itemsPerPage, offset: currentPage * itemsPerPage)
        searchResults.append(contentsOf: moreResults)
        sortSearchResults()
    }

    private func sortSearchResults() {
        searchResults.sort { (photo1, photo2) in
            let date1 = dateFromString(photo1.dateTimeOriginal)
            let date2 = dateFromString(photo2.dateTimeOriginal)
            return sortOrder == .ascending ? date1 < date2 : date1 > date2
        }
    }

    private func dateFromString(_ dateString: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.date(from: dateString) ?? Date.distantPast
    }
}
