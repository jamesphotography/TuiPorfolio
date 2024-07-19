import SwiftUI

struct SearchView: View {
    @State private var searchText: String = ""
    @State private var searchResults: [Photo] = []
    @State private var showSearchResults = false
    @State private var totalResults: Int = 0
    @State private var hotSearches: [String] = HotSearchManager.shared.getHotSearches()
    @State private var currentPage = 0
    let itemsPerPage = 9

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
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .foregroundColor(Color("TUIBLUE"))
                                .padding(.leading, 8)
                            TextField("Search", text: $searchText, onCommit: performSearch)
                                .font(.caption2)
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

                    // 搜索结果数量
                    if showSearchResults {
                        Text("Found \(totalResults) photos")
                            .font(.caption2)
                            .padding(.leading, 16)
                            .padding(.top, 8)
                    }

                    // 热门搜索项
                    if !showSearchResults {
                        VStack(alignment: .leading) {
                            Text("Popular Searches")
                                .font(.caption2)
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
                                            .font(.caption2)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .stroke(Color("TUIBLUE"), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .padding()
                        }
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

    private func performSearch() {
        totalResults = SQLiteManager.shared.countPhotos(keyword: searchText)
        searchResults = SQLiteManager.shared.searchPhotos(keyword: searchText, limit: itemsPerPage, offset: 0)
        currentPage = 0
        showSearchResults = true

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
    }
}
