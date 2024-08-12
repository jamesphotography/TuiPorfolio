import SwiftUI
import Charts

struct Project365View: View {
    @State private var longestStreakStart: Date?
    @State private var longestStreakDays: Int = 0
    @State private var longestStreakEnd: Date?
    @State private var currentStreak: Int = 0
    @State private var selectedDate: Date?
    
    let colors: [Color] = [.red, .blue, .green, .orange, .purple]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: "Project365")
                    .padding(.top, geometry.safeAreaInsets.top)
                
                ScrollView {
                    VStack(spacing: 20) {
                        Project365CardView(longestStreakStart: longestStreakStart,
                                           longestStreakDays: longestStreakDays,
                                           longestStreakEnd: longestStreakEnd,
                                           currentStreak: currentStreak,
                                           selectedDate: $selectedDate)
                            .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.5)
                        
                        Spacer()
                        
                        StreakChartView(currentStreak: currentStreak, longestStreak: longestStreakDays, colors: colors)
                            .frame(height: 200)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(Color("BGColor"))
                }
                
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear(perform: calculateStreak)
        .navigationDestination(isPresented: Binding(
            get: { selectedDate != nil },
            set: { if !$0 { selectedDate = nil } }
        )) {
            if let date = selectedDate {
                CalendarView(date: date)
            }
        }
    }
    
    func calculateStreak() {
        let sqliteManager = SQLiteManager.shared
        let allPhotos = sqliteManager.getAllPhotos(sortByShootingTime: true)
        
        guard !allPhotos.isEmpty else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var datesWithPhotos = Set<String>()
        for photo in allPhotos {
            let dateString = String(photo.dateTimeOriginal.prefix(10))
            datesWithPhotos.insert(dateString)
        }
        
        let sortedDates = datesWithPhotos.sorted()
        
        var longestStreak = 0
        var currentStreak = 0
        var longestStreakStart: String?
        var longestStreakEnd: String?
        var currentStreakStart: String?
        
        for (index, date) in sortedDates.enumerated() {
            if index == 0 {
                currentStreak = 1
                currentStreakStart = date
            } else {
                let previousDate = sortedDates[index - 1]
                let daysBetween = Calendar.current.dateComponents([.day], from: dateFormatter.date(from: previousDate)!, to: dateFormatter.date(from: date)!).day!
                
                if daysBetween == 1 {
                    currentStreak += 1
                } else {
                    if currentStreak > longestStreak {
                        longestStreak = currentStreak
                        longestStreakStart = currentStreakStart
                        longestStreakEnd = sortedDates[index - 1]
                    }
                    currentStreak = 1
                    currentStreakStart = date
                }
            }
        }
        
        if currentStreak > longestStreak {
            longestStreak = currentStreak
            longestStreakStart = currentStreakStart
            longestStreakEnd = sortedDates.last
        }
        
        if let start = longestStreakStart, let end = longestStreakEnd {
            self.longestStreakStart = dateFormatter.date(from: start)
            self.longestStreakEnd = dateFormatter.date(from: end)
            self.longestStreakDays = longestStreak
        }
        
        let today = Date()
        let todayString = dateFormatter.string(from: today)
        if datesWithPhotos.contains(todayString) {
            var currentStreakLength = 1
            var currentDate = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            
            while datesWithPhotos.contains(dateFormatter.string(from: currentDate)) {
                currentStreakLength += 1
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
            }
            
            self.currentStreak = currentStreakLength
        } else {
            self.currentStreak = 0
        }
    }
}

struct Project365CardView: View {
    var longestStreakStart: Date?
    var longestStreakDays: Int
    var longestStreakEnd: Date?
    var currentStreak: Int
    @Binding var selectedDate: Date?
    
    var body: some View {
        VStack {
            Spacer(minLength: 20)
            Image("tuiblueapp")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Text("Project365 Statistics")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let start = longestStreakStart {
                    HStack {
                        Text("Best attempt started on ")
                            .foregroundColor(.white)
                        Text(formattedDate(start))
                            .foregroundColor(.white)
                            .underline()
                            .onTapGesture {
                                selectedDate = start
                            }
                    }
                }
                
                Text("Longest streak: \(longestStreakDays) days")
                    .foregroundColor(.white)
                
                if let end = longestStreakEnd {
                    HStack {
                        Text("Ended on ")
                            .foregroundColor(.white.opacity(0.8))
                        Text(formattedDate(end))
                            .foregroundColor(.white.opacity(0.8))
                            .underline()
                            .onTapGesture {
                                selectedDate = end
                            }
                    }
                }
                
                Spacer()
                
                if currentStreak > 0 {
                    Text("Current streak: \(currentStreak) days")
                        .foregroundColor(.green)
                    Text("Keep going! \(365 - currentStreak) days left to complete Project365")
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("No active streak. Start shooting today!")
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 20)
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 20)
        }
        .padding(.vertical, 20)
        .background(Color("TUIBLUE"))
        .cornerRadius(15)
        .shadow(radius: 10)
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct StreakChartView: View {
    var currentStreak: Int
    var longestStreak: Int
    var colors: [Color]
    
    var body: some View {
        VStack {
            Text("Streak Comparison")
                .font(.headline)
                .padding(.bottom)
            
            Chart {
                BarMark(
                    x: .value("Type", "Current"),
                    y: .value("Days", currentStreak)
                )
                .foregroundStyle(colors[0])
                
                BarMark(
                    x: .value("Type", "Longest"),
                    y: .value("Days", longestStreak)
                )
                .foregroundStyle(colors[1])
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
    }
}

struct Project365View_Previews: PreviewProvider {
    static var previews: some View {
        Project365View()
    }
}
