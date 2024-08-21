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
                    LazyVStack(spacing: 5) {
                        CustomCalendarView(date: $selectedDate, specialDates: datesWithPhotos)
                            .frame(height: geometry.size.width * 0.85)
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
                        } else {
                            Text("No photos for this date")
                                .foregroundColor(.gray)
                                .frame(height: 100)
                        }
                        
                        NavigationLink(destination: Project365View()) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.5))
                                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                                
                                VStack(spacing: 10) {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: 50))
                                        .foregroundColor(Color("TUIBLUE"))
                                    
                                    Text("PROJECT 365")
                                        .font(.subheadline)
                                        .foregroundColor(Color("TUIBLUE"))
                                }
                            }
                            .frame(width: 150, height: 150)
                        }
                        .padding(.vertical, 20)
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
        VStack(alignment: .leading, spacing: 20) {
            HStack{
                Spacer()
                Text(" \(formattedDate(currentDate))")
                    .padding(.top,15)
                    .font(.headline)
                    .foregroundColor(Color("TUIBLUE"))
                Spacer()
            }
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
            .frame(height: calculateGridHeight())
            
            if photos.count > 30 {
                NavigationLink(destination: MorePhotosView(date: formattedDate(currentDate))) {
                    Text("View All Photos")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 10)
                }
            }
        }
        .padding(10)
    }
    
    private func calculateGridHeight() -> CGFloat {
        let photoCount = min(photos.count, 9)
        let rows = ceil(Double(photoCount) / 3.0)
        return (UIScreen.main.bounds.width - spacing * 2) / 3 * CGFloat(rows) + spacing * (CGFloat(rows) - 1)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
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
