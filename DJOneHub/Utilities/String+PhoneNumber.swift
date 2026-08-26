import Foundation

// MARK: - 电话号码处理扩展
extension String {
    
    /// 格式化电话号码为易读格式
    var formattedPhoneNumber: String {
        let digits = self.digitsOnly
        
        // 中国大陆手机号 11位
        if digits.count == 11 && digits.hasPrefix("1") {
            let index3 = digits.index(digits.startIndex, offsetBy: 3)
            let index7 = digits.index(digits.startIndex, offsetBy: 7)
            return "\(digits[..<index3]) \(digits[index3..<index7]) \(digits[index7...])"
        }
        
        // 带国际区号
        if digits.hasPrefix("86") && digits.count == 13 {
            let index2 = digits.index(digits.startIndex, offsetBy: 2)
            let index5 = digits.index(digits.startIndex, offsetBy: 5)
            let index9 = digits.index(digits.startIndex, offsetBy: 9)
            return "+86 \(digits[index2..<index5]) \(digits[index5..<index9]) \(digits[index9...])"
        }
        
        return self
    }
    
    /// 仅保留数字
    var digitsOnly: String {
        components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
    
    /// 是否为有效的电话号码
    var isValidPhoneNumber: Bool {
        let digits = self.digitsOnly
        // 简单验证：至少7位数字
        return digits.count >= 7 && digits.count <= 15
    }
    
    /// 移除国际区号前缀
    var withoutCountryCode: String {
        var digits = self.digitsOnly
        if digits.hasPrefix("86") && digits.count > 11 {
            digits = String(digits.dropFirst(2))
        }
        if digits.hasPrefix("0086") {
            digits = String(digits.dropFirst(4))
        }
        return digits
    }
    
    /// 匹配两个电话号码是否相同（忽略格式和区号）
    func matchesPhoneNumber(_ other: String) -> Bool {
        return self.withoutCountryCode == other.withoutCountryCode
    }
}
