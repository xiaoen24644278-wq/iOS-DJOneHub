import Foundation

// MARK: - 通话记录模型
struct CallRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let phoneNumber: String
    let contactName: String?
    let timestamp: Date
    let duration: TimeInterval
    let callType: CallType
    let isMissed: Bool
    
    enum CallType: String, Codable {
        case incoming = "incoming"
        case outgoing = "outgoing"
        case missed = "missed"
    }
    
    var durationString: String {
        if duration < 60 {
            return "\(Int(duration))秒"
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return "\(minutes)分\(seconds)秒"
        }
    }
    
    init(id: UUID = UUID(),
         phoneNumber: String,
         contactName: String? = nil,
         timestamp: Date = Date(),
         duration: TimeInterval = 0,
         callType: CallType,
         isMissed: Bool = false) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.contactName = contactName
        self.timestamp = timestamp
        self.duration = duration
        self.callType = callType
        self.isMissed = isMissed
    }
}

// MARK: - 通话状态
enum CallState: Equatable {
    case idle
    case dialing(number: String)
    case incoming(number: String, contactName: String?)
    case connecting(number: String)
    case active(number: String, duration: TimeInterval, isMuted: Bool, isSpeaker: Bool)
    case held(number: String)
    case ended(reason: CallEndReason)
    
    enum CallEndReason {
        case normal
        case missed
        case rejected
        case failed
        case busy
    }
}
