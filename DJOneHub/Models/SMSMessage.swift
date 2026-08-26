import Foundation

// MARK: - 短信消息模型
struct SMSMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let phoneNumber: String
    let content: String
    let timestamp: Date
    let direction: Direction
    let isRead: Bool
    let isVerificationCode: Bool
    
    enum Direction: String, Codable {
        case incoming = "incoming"
        case outgoing = "outgoing"
    }
    
    init(id: UUID = UUID(),
         phoneNumber: String,
         content: String,
         timestamp: Date = Date(),
         direction: Direction,
         isRead: Bool = false,
         isVerificationCode: Bool = false) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.content = content
        self.timestamp = timestamp
        self.direction = direction
        self.isRead = isRead
        self.isVerificationCode = isVerificationCode
    }
}

// MARK: - 短信会话模型
struct SMSConversation: Identifiable, Hashable {
    let id: String
    let phoneNumber: String
    let contactName: String?
    var messages: [SMSMessage]
    var unreadCount: Int
    
    var latestMessage: SMSMessage? {
        messages.last
    }
    
    init(phoneNumber: String, contactName: String? = nil, messages: [SMSMessage] = []) {
        self.id = phoneNumber
        self.phoneNumber = phoneNumber
        self.contactName = contactName
        self.messages = messages
        self.unreadCount = messages.filter { !$0.isRead && $0.direction == .incoming }.count
    }
}
