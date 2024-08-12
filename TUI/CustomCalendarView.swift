import SwiftUI

struct CustomCalendarView: View {
    @Binding var selectedDate: Date?
    let specialDates: Set<Date>
    private let calendar = Calendar.current
    @State private var showYearPicker = false
    @State private var selectedYear: Int
    
    init(date: Binding<Date?>, specialDates: Set<Date>) {
        self._selectedDate = date
        self.specialDates = specialDates
        let year = Calendar.current.component(.year, from: date.wrappedValue ?? Date())
        self._selectedYear = State(initialValue: year)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 3) {
                monthHeader
                weekdayHeader
                monthGrid
            }
            .padding()
            .background(Color("TUIBLUE"))
            .cornerRadius(10)
            .shadow(radius: 5)
            .frame(width: geometry.size.width, height: geometry.size.width)
            .overlay(
                Group {
                    if showYearPicker {
                        yearPicker
                    }
                }
            )
        }
        .foregroundColor(.white)
    }
    
    private var monthHeader: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left").padding()
            }
            
            Spacer()
            
            HStack {
                Text(monthString(from: selectedDate ?? Date()))
                    .font(.headline)
                Button(action: {
                    showYearPicker = true
                }) {
                    Text(String(selectedYear))
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(15)
                }
            }
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right").padding()
            }
        }
    }
    
    private var weekdayHeader: some View {
        HStack {
            ForEach(0..<7, id: \.self) { index in
                Text(getDayOfWeek(index))
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var monthGrid: some View {
        let days = generateDaysInMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 3) {
            ForEach(days.indices, id: \.self) { index in
                if let date = days[index] {
                    dayCell(for: date)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }
    
    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate ?? Date())
        let isSpecial = specialDates.contains { calendar.isDate($0, inSameDayAs: date) }
        
        return Text(date.dayString)
            .frame(width:40 , height: 40)
            .background(isSelected ? Color.blue.opacity(0.3) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .overlay(
                Circle()
                    .fill(isSpecial ? Color.red : Color.clear)
                    .frame(width: 8, height: 8)
                    .offset(x: 15, y: 15)
            )
            .onTapGesture {
                selectedDate = date
            }
    }
    
    private var yearPicker: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack {
                    Text("Select Year")
                        .font(.headline)
                        .padding()
                    
                    Picker("Year", selection: $selectedYear) {
                        ForEach((1977...2077), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 150, height: 150)
                    .clipped()
                    
                    Button("Done") {
                        if let currentDate = selectedDate {
                            let components = calendar.dateComponents([.month, .day], from: currentDate)
                            var newComponents = DateComponents()
                            newComponents.year = selectedYear
                            newComponents.month = components.month
                            newComponents.day = components.day
                            if let newDate = calendar.date(from: newComponents) {
                                selectedDate = newDate
                            }
                        }
                        showYearPicker = false
                    }
                    .padding()
                }
                .background(Color.white)
                .cornerRadius(15)
                .foregroundColor(.black)
                Spacer()
            }
            Spacer()
        }
        .background(Color.black.opacity(0.5))
        .edgesIgnoringSafeArea(.all)
    }
    
    private func previousMonth() {
        if let currentDate = selectedDate {
            selectedDate = calendar.date(byAdding: .month, value: -1, to: currentDate)
            updateSelectedYear()
        }
    }
    
    private func nextMonth() {
        if let currentDate = selectedDate {
            selectedDate = calendar.date(byAdding: .month, value: 1, to: currentDate)
            updateSelectedYear()
        }
    }
    
    private func updateSelectedYear() {
        if let date = selectedDate {
            selectedYear = calendar.component(.year, from: date)
        }
    }
    
    private func monthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }
    
    private func getDayOfWeek(_ index: Int) -> String {
        let formatter = DateFormatter()
        return formatter.shortWeekdaySymbols[index]
    }
    
    private func generateDaysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate ?? Date()),
              let firstWeekday = calendar.date(from: calendar.dateComponents([.year, .month], from: monthInterval.start))
        else {
            return []
        }

        let daysInMonth = calendar.range(of: .day, in: .month, for: monthInterval.start)!
        
        let startOffset = calendar.component(.weekday, from: firstWeekday) - 1
        let totalDays = startOffset + daysInMonth.count
        let endOffset = (7 - (totalDays % 7)) % 7
        
        var days: [Date?] = Array(repeating: nil, count: startOffset)
        
        for day in daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstWeekday) {
                days.append(date)
            }
        }
        
        days += Array(repeating: nil, count: endOffset)
        
        return days
    }
}

extension Date {
    var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: self)
    }
    
    func toString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}
