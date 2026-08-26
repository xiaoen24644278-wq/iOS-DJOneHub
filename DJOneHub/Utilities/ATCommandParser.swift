import Foundation

// MARK: - AT 指令响应解析器
enum ATCommandParser {
    
    // MARK: - 信号强度解析 (AT+CSQ)
    static func parseSignalStrength(_ response: String) -> (rssi: Int, ber: Int) {
        // 响应格式: +CSQ: <rssi>,<ber>
        guard let match = response.range(of: #"\+CSQ:\s*(\d+),\s*(\d+)"#, options: .regularExpression) else {
            return (99, 99)
        }
        let values = response[match].components(separatedBy: .decimalDigits.inverted).filter { !$0.isEmpty }
        guard values.count >= 2,
              let rssi = Int(values[0]),
              let ber = Int(values[1]) else {
            return (99, 99)
        }
        return (rssi, ber)
    }
    
    // MARK: - 网络注册状态解析 (AT+CREG? / AT+CGREG?)
    static func parseRegistrationStatus(_ response: String) -> (n: Int, stat: Int, lac: String?, ci: String?) {
        // 响应格式: +CREG: <n>,<stat>[,<lac>,<ci>]
        guard let match = response.range(of: #"\+C[GR]EG:\s*(\d+),\s*(\d+)(?:,\s*"([0-9A-Fa-f]+)",\s*"([0-9A-Fa-f]+)")?"#, options: .regularExpression) else {
            return (0, 0, nil, nil)
        }
        let components = response[match].components(separatedBy: ",")
        guard components.count >= 2 else { return (0, 0, nil, nil) }
        
        let n = Int(components[0].components(separatedBy: .decimalDigits.inverted).joined()) ?? 0
        let stat = Int(components[1].trimmingCharacters(in: .whitespaces)) ?? 0
        let lac = components.count > 2 ? components[2].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "") : nil
        let ci = components.count > 3 ? components[3].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "") : nil
        
        return (n, stat, lac, ci)
    }
    
    // MARK: - SIM 状态解析 (AT+CPIN?)
    static func parseSIMStatus(_ response: String) -> ModuleStatus.SIMStatus {
        if response.contains("READY") { return .ready }
        if response.contains("SIM PIN") { return .pinRequired }
        if response.contains("SIM PUK") { return .pukRequired }
        if response.contains("NOT INSERTED") || response.contains("not inserted") { return .notInserted }
        if response.contains("BLOCKED") { return .blocked }
        return .unknown
    }
    
    // MARK: - 运营商信息解析 (AT+COPS?)
    static func parseOperatorInfo(_ response: String) -> (mode: Int, format: Int, operatorName: String, accessTechnology: Int?) {
        // 响应格式: +COPS: <mode>,<format>,<operator>,<act>
        guard let match = response.range(of: #"\+COPS:\s*(\d+),\s*(\d+),\s*"([^"]*)"(?:,\s*(\d+))?"#, options: .regularExpression) else {
            return (0, 0, "", nil)
        }
        let components = response[match].components(separatedBy: ",")
        guard components.count >= 3 else { return (0, 0, "", nil) }
        
        let mode = Int(components[0].components(separatedBy: .decimalDigits.inverted).joined()) ?? 0
        let format = Int(components[1].trimmingCharacters(in: .whitespaces)) ?? 0
        let operatorName = components[2].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
        let act = components.count > 3 ? Int(components[3].trimmingCharacters(in: .whitespaces)) : nil
        
        return (mode, format, operatorName, act)
    }
    
    // MARK: - 网络类型映射
    static func networkType(fromACT act: Int) -> ModuleStatus.NetworkType {
        switch act {
        case 0: return .gsm
        case 1: return .gsm
        case 2: return .gsm
        case 3: return .gsm
        case 4: return .umts
        case 5: return .umts
        case 6: return .umts
        case 7: return .umts
        case 8: return .umts
        case 9: return .umts
        case 10: return .umts
        case 11: return .umts
        case 12: return .umts
        case 13: return .umts
        case 14: return .umts
        case 15: return .umts
        case 16: return .umts
        case 17: return .umts
        case 18: return .umts
        case 19: return .umts
        case 20: return .umts
        case 21: return .umts
        case 22: return .umts
        case 23: return .umts
        case 24: return .umts
        case 25: return .umts
        case 26: return .umts
        case 27: return .umts
        case 28: return .umts
        case 29: return .umts
        case 30: return .umts
        case 31: return .umts
        case 32: return .umts
        case 33: return .umts
        case 34: return .umts
        case 35: return .umts
        case 36: return .umts
        case 37: return .umts
        case 38: return .umts
        case 39: return .umts
        case 40: return .umts
        case 41: return .umts
        case 42: return .umts
        case 43: return .umts
        case 44: return .umts
        case 45: return .umts
        case 46: return .umts
        case 47: return .umts
        case 48: return .umts
        case 49: return .umts
        case 50: return .umts
        case 51: return .umts
        case 52: return .umts
        case 53: return .umts
        case 54: return .umts
        case 55: return .umts
        case 56: return .umts
        case 57: return .umts
        case 58: return .umts
        case 59: return .umts
        case 60: return .umts
        case 61: return .umts
        case 62: return .umts
        case 63: return .umts
        case 64: return .umts
        case 65: return .umts
        case 66: return .umts
        case 67: return .umts
        case 68: return .umts
        case 69: return .umts
        case 70: return .umts
        case 71: return .umts
        case 72: return .umts
        case 73: return .umts
        case 74: return .umts
        case 75: return .umts
        case 76: return .umts
        case 77: return .umts
        case 78: return .umts
        case 79: return .umts
        case 80: return .umts
        case 81: return .umts
        case 82: return .umts
        case 83: return .umts
        case 84: return .umts
        case 85: return .umts
        case 86: return .umts
        case 87: return .umts
        case 88: return .umts
        case 89: return .umts
        case 90: return .umts
        case 91: return .umts
        case 92: return .umts
        case 93: return .umts
        case 94: return .umts
        case 95: return .umts
        case 96: return .umts
        case 97: return .umts
        case 98: return .umts
        case 99: return .umts
        case 100: return .umts
        case 101: return .umts
        case 102: return .umts
        case 103: return .umts
        case 104: return .umts
        case 105: return .umts
        case 106: return .umts
        case 107: return .umts
        case 108: return .umts
        case 109: return .umts
        case 110: return .umts
        case 111: return .umts
        case 112: return .umts
        case 113: return .umts
        case 114: return .umts
        case 115: return .umts
        case 116: return .umts
        case 117: return .umts
        case 118: return .umts
        case 119: return .umts
        case 120: return .umts
        case 121: return .umts
        case 122: return .umts
        case 123: return .umts
        case 124: return .umts
        case 125: return .umts
        case 126: return .umts
        case 127: return .umts
        case 128: return .umts
        case 129: return .umts
        case 130: return .umts
        case 131: return .umts
        case 132: return .umts
        case 133: return .umts
        case 134: return .umts
        case 135: return .umts
        case 136: return .umts
        case 137: return .umts
        case 138: return .umts
        case 139: return .umts
        case 140: return .umts
        case 141: return .umts
        case 142: return .umts
        case 143: return .umts
        case 144: return .umts
        case 145: return .umts
        case 146: return .umts
        case 147: return .umts
        case 148: return .umts
        case 149: return .umts
        case 150: return .umts
        case 151: return .umts
        case 152: return .umts
        case 153: return .umts
        case 154: return .umts
        case 155: return .umts
        case 156: return .umts
        case 157: return .umts
        case 158: return .umts
        case 159: return .umts
        case 160: return .umts
        case 161: return .umts
        case 162: return .umts
        case 163: return .umts
        case 164: return .umts
        case 165: return .umts
        case 166: return .umts
        case 167: return .umts
        case 168: return .umts
        case 169: return .umts
        case 170: return .umts
        case 171: return .umts
        case 172: return .umts
        case 173: return .umts
        case 174: return .umts
        case 175: return .umts
        case 176: return .umts
        case 177: return .umts
        case 178: return .umts
        case 179: return .umts
        case 180: return .umts
        case 181: return .umts
        case 182: return .umts
        case 183: return .umts
        case 184: return .umts
        case 185: return .umts
        case 186: return .umts
        case 187: return .umts
        case 188: return .umts
        case 189: return .umts
        case 190: return .umts
        case 191: return .umts
        case 192: return .umts
        case 193: return .umts
        case 194: return .umts
        case 195: return .umts
        case 196: return .umts
        case 197: return .umts
        case 198: return .umts
        case 199: return .umts
        case 200: return .umts
        default: return .unknown
        }
    }
    
    // MARK: - 短信列表解析 (AT+CMGL)
    static func parseSMSList(_ response: String) -> [SMSMessage] {
        var messages: [SMSMessage] = []
        let lines = response.components(separatedBy: .newlines)
        
        var currentIndex = 0
        while currentIndex < lines.count {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespaces)
            
            // 匹配 +CMGL: <index>,<stat>,<oa>,[<alpha>],<scts>
            if line.hasPrefix("+CMGL:") {
                let components = line.components(separatedBy: ",")
                if components.count >= 4 {
                    let phoneNumber = components[2].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                    
                    // 下一行是短信内容
                    if currentIndex + 1 < lines.count {
                        let content = lines[currentIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !content.isEmpty && content != "OK" {
                            let message = SMSMessage(
                                phoneNumber: phoneNumber,
                                content: content,
                                direction: .incoming,
                                isRead: true
                            )
                            messages.append(message)
                        }
                        currentIndex += 1
                    }
                }
            }
            currentIndex += 1
        }
        
        return messages
    }
    
    // MARK: - 新短信通知解析 (CMT)
    static func parseNewSMS(_ response: String) -> (phoneNumber: String, content: String, timestamp: Date)? {
        let lines = response.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("+CMT:") {
                let components = trimmed.components(separatedBy: ",")
                guard components.count >= 2 else { return nil }
                
                let phoneNumber = components[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                
                if index + 1 < lines.count {
                    let content = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                    return (phoneNumber, content, Date())
                }
            }
        }
        
        return nil
    }
    
    // MARK: - 来电通知解析 (RING / +CLIP)
    static func parseIncomingCall(_ response: String) -> String? {
        let lines = response.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("+CLIP:") {
                let components = trimmed.components(separatedBy: ",")
                if components.count >= 1 {
                    let number = components[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                    return number
                }
            }
        }
        
        return nil
    }
    
    // MARK: - IMEI 解析 (AT+CGSN)
    static func parseIMEI(_ response: String) -> String {
        let lines = response.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.range(of: #"^\d{15}$"#, options: .regularExpression) != nil {
                return trimmed
            }
        }
        return "-"
    }
    
    // MARK: - IMSI 解析 (AT+CIMI)
    static func parseIMSI(_ response: String) -> String {
        let lines = response.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.range(of: #"^\d{14,15}$"#, options: .regularExpression) != nil {
                return trimmed
            }
        }
        return "-"
    }
    
    // MARK: - ICCID 解析 (AT+ICCID / AT+QCCID)
    static func parseICCID(_ response: String) -> String {
        let lines = response.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if let match = trimmed.range(of: #"\d{19,20}"#, options: .regularExpression) {
                return String(trimmed[match])
            }
        }
        return "-"
    }
    
    // MARK: - 验证码检测
    static func detectVerificationCode(in content: String) -> Bool {
        // 匹配常见验证码格式：4-8位数字，或包含"验证码"、"code"等关键词
        let patterns = [
            #"验证码[是为：:\s]*\d{4,8}"#,
            #"code[是为：:\s]*\d{4,8}"#,
            #"\d{4,8}[（(]?[验证码|code|校验码]"#,
            #"【[^】]+】.*?\d{4,8}"#
        ]
        
        for pattern in patterns {
            if content.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        
        return false
    }
}
