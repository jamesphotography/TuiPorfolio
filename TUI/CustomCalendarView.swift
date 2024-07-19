import SwiftUI

struct CustomCalendarView: View {
    @Binding var selectedDate: Date?
    let specialDates: Set<Date>
    private let calendar = Calendar.current
    
    init(date: Binding<Date?>, specialDates: Set<Date>) {
        self._selectedDate = date
        self.specialDates = specialDates
        print("CustomCalendarView initialized with \(specialDates.count) special dates")
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
        }
        .onAppear {
            print("CustomCalendarView appeared with \(specialDates.count) special dates")
        }
        .foregroundColor(.white)
    }
    
    private var monthHeader: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left").padding()
            }
            
            Text(monthYearString(from: selectedDate ?? Date()))
                .font(.headline)
                .padding()
            
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
                print("Selected date: \(date.toString())")
            }
    }
    
    private func previousMonth() {
        if let currentDate = selectedDate {
            selectedDate = calendar.date(byAdding: .month, value: -1, to: currentDate)
        }
    }
    
    private func nextMonth() {
        if let currentDate = selectedDate {
            selectedDate = calendar.date(byAdding: .month, value: 1, to: currentDate)
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
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


// 预览提供者
struct CustomCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        let currentDate = Date()
        let calendar = Calendar.current
        
        // 创建一些特殊日期用于预览
        let specialDates: Set<Date> = [
            calendar.date(byAdding: .day, value: -1, to: currentDate)!,
            calendar.date(byAdding: .day, value: 2, to: currentDate)!,
            calendar.date(byAdding: .day, value: 5, to: currentDate)!
        ]
        
        return CustomCalendarView(
            date: .constant(currentDate),
            specialDates: specialDates
        )
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.gray) // 添加背景色以便于查看白色文本
    }
}
