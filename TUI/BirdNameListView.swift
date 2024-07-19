import SwiftUI

struct BirdInfo: Identifiable {
    let id = UUID()
    let names: [String]
}

struct BirdNameListView: View {
    @State private var searchText: String = ""
    @State private var allBirds: [BirdInfo] = []
    @State private var searchResults: [BirdInfo] = []
    @State private var showSearchResults = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hotSearches: [String] = []
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Headbar
                HeadBarView(title: NSLocalizedString("Bird Name Search", comment: ""))
                    .padding(.top, geometry.safeAreaInsets.top)
                
                // Main content
                VStack(spacing: 8) {
                    // Search bar
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .foregroundColor(Color("TUIBLUE"))
                                .padding(.leading, 8)
                            TextField("Search bird name", text: $searchText, onCommit: performSearch)
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
                    
                    if isLoading {
                        ProgressView("Loading...")
                            .padding()
                    } else if let error = errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    } else if showSearchResults {
                        // Search results
                        List(searchResults) { bird in
                            VStack(alignment: .leading) {
                                ForEach(bird.names, id: \.self) { name in
                                    Text(name)
                                        .font(name == bird.names.first ? .headline : .subheadline)
                                }
                            }
                        }
                    } else {
                        // Hot searches
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
                    }
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
        .onAppear(perform: loadBirdInfo)
    }
    
    private func loadBirdInfo() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .background).async {
            do {
                let birdList = try loadBirdList()
                let birdInfoList = birdList.map { BirdInfo(names: $0) }
                
                DispatchQueue.main.async {
                    self.allBirds = birdInfoList
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadBirdList() throws -> [[String]] {
        guard let url = Bundle.main.url(forResource: "birdInfo", withExtension: "json") else {
            throw NSError(domain: "BirdNameListView", code: 1, userInfo: [NSLocalizedDescriptionKey: "birdInfo.json file not found"])
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([[String]].self, from: data)
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            showSearchResults = false
            return
        }
        
        searchResults = allBirds.filter { bird in
            bird.names.contains { $0.lowercased().contains(searchText.lowercased()) }
        }
        
        showSearchResults = true
        
        // Update hot searches
        if !hotSearches.contains(searchText) {
            hotSearches.insert(searchText, at: 0)
            if hotSearches.count > 10 {
                hotSearches.removeLast()
            }
        }
        
        // Hide keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct BirdNameListView_Previews: PreviewProvider {
    static var previews: some View {
        BirdNameListView()
    }
}
