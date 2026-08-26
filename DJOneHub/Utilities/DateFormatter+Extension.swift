import Foundation

// MARK: - 日期格式化扩展
extension DateFormatter {
    static let messageTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
    
    static let messageDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
    
    static let callRecordTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
    
    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
    
    static let relativeDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

// MARK: - 日期相对描述
extension Date {
    var relativeDescription: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(self) {
            return "今天 \(DateFormatter.messageTime.string(from: self))"
        } else if calendar.isDateInYesterday(self) {
            return "昨天 \(DateFormatter.messageTime.string(from: self))"
        } else {
            return DateFormatter.messageDate.string(from: self)
        }
    }
    
    var shortTimeDescription: String {
        DateFormatter.messageTime.string(from: self)
    }
}
