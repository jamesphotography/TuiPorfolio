import SwiftUI

struct CalendarView: View {
    @State private var currentDate: Date
    @State private var selectedDate: Date?
    @State private var currentMonth: Date
    @State private var photos: [Photo] = []
    @State private var datesWithPhotos: Set<Date> = []
    private let calendar = Calendar.current
    
    init(date: Date? = nil) {
        let defaultDate = date ?? Date()
        self._currentDate = State(initialValue: defaultDate)
        self._selectedDate = State(initialValue: defaultDate)
        self._currentMonth = State(initialValue: defaultDate)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: NSLocalizedString("Calendar", comment: ""))
                    .padding(.top, geometry.safeAreaInsets.top)
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        CustomCalendarView(date: $selectedDate, specialDates: datesWithPhotos)
                            .frame(height: geometry.size.width * 0.8)
                            .onAppear {
                                loadDatesWithPhotos(for: currentMonth)
                                loadPhotos(for: selectedDate ?? currentDate)
                            }
                            .onChange(of: selectedDate) { oldValue, newValue in
                                if let date = newValue {
                                    loadPhotos(for: date)
                                    loadDatesWithPhotos(for: date)
                                }
                            }
                        
                        if !photos.isEmpty {
                            SameDayPhotoGrid(photos: photos, currentDate: selectedDate ?? currentDate)
                                .frame(minHeight: 200)
                        } else {
                            Text("No photos for this date")
                                .foregroundColor(.gray)
                                .frame(height: 200)
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
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            if selectedDate == nil {
                selectedDate = currentDate
            }
        }
    }
    
    private func loadPhotos(for date: Date) {
        let dateString = formattedDate(date)
        photos = SQLiteManager.shared.getPhotos(for: dateString)
        print("Loaded \(photos.count) photos for date: \(dateString)")
    }
    
    private func loadDatesWithPhotos(for date: Date) {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        
        datesWithPhotos.removeAll()
        
        for day in range {
            let dateToCheck = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)!
            let dateString = formattedDate(dateToCheck)
            if !SQLiteManager.shared.getPhotos(for: dateString).isEmpty {
                datesWithPhotos.insert(dateToCheck)
            }
        }
        
        print("Loaded \(datesWithPhotos.count) dates with photos for month: \(formattedDate(date))")
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct SameDayPhotoGrid: View {
    var photos: [Photo]
    var currentDate: Date
    
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private let spacing: CGFloat = 15
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photos taken on \(formattedDate(currentDate))")
                .font(.headline)
                .padding(.vertical, 5)
            
            GeometryReader { geometry in
                let size = (geometry.size.width - spacing * 2) / 3
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(Array(photos.prefix(9).enumerated()), id: \.element.id) { index, photo in
                        NavigationLink(destination: DetailView(photos: photos, initialIndex: photos.firstIndex(where: { $0.id == photo.id }) ?? 0, onDismiss: { _ in })) {
                            PhotoThumbnailView(photo: photo, size: size)
                        }
                    }
                }
            }
            .frame(height: (UIScreen.main.bounds.width - spacing * 2) / 3 * 3 + spacing * 2)
            
            if photos.count > 9 {
                NavigationLink(destination: MorePhotosView(date: formattedDate(currentDate))) {
                    Text("View All Photos")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 5)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct MorePhotosView: View {
    var date: String
    @State private var photos: [Photo] = []
    
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private let spacing: CGFloat = 10
    
    var body: some View {
        ScrollView {
            GeometryReader { geometry in
                let size = (geometry.size.width - spacing * 2) / 3
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        NavigationLink(destination: DetailView(photos: photos, initialIndex: photos.firstIndex(where: { $0.id == photo.id }) ?? 0, onDismiss: { _ in })) {
                            PhotoThumbnailView(photo: photo, size: size)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Photos on \(date)")
        .onAppear {
            loadPhotos()
        }
    }
    
    private func loadPhotos() {
        photos = SQLiteManager.shared.getPhotos(for: date)
    }
}

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView()
    }
}
