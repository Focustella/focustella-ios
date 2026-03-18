import Foundation

extension Date {
    /// 06시를 기준으로 논리적인 날짜를 반환합니다. (예: 16일 새벽 2시 -> "2026-03-15")
    var logicalDateString: String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        let logicalDate = hour < 6 ? calendar.date(byAdding: .day, value: -1, to: self)! : self
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: logicalDate)
    }
}
