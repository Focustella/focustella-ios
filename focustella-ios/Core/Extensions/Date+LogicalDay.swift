import Foundation

extension Date {
    /// 06시를 기준으로 논리적인 '오늘'의 시작 시간을 반환합니다.
    var logicalDayStart: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: self)
        
        if let hour = components.hour, hour < 6 {
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: self))!.addingTimeInterval(6 * 3600)
        } else {
            return calendar.startOfDay(for: self).addingTimeInterval(6 * 3600)
        }
    }
}
