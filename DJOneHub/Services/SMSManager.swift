import Foundation
import Combine
import UserNotifications

// MARK: - 短信管理器
final class SMSManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = SMSManager()
    
    // MARK: - 发布属性
    @Published private(set) var conversations: [SMSConversation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var unreadCount = 0
    
    // MARK: - 私有属性
    private let atManager = ATCommandManager.shared
    private let userDefaults = UserDefaults.standard
    
    // MARK: - 初始化
    private init() {
        loadCachedMessages()
        setupCallbacks()
    }
    
    // MARK: - 设置回调
    private func setupCallbacks() {
        atManager.onNewSMS = { [weak self] phoneNumber, content in
            self?.handleIncomingSMS(phoneNumber: phoneNumber, content: content)
        }
    }
    
    // MARK: - 加载缓存消息
    private func loadCachedMessages() {
        guard let data = userDefaults.data(forKey: UserDefaultsKeys.smsMessages),
              let messages = try? JSONDecoder().decode([SMSMessage].self, from: data) else {
            return
        }
        
        // 按号码分组
        conversations = groupMessagesByPhoneNumber(messages)
        updateUnreadCount()
    }
    
    // MARK: - 保存缓存
    private func saveCachedMessages() {
        let allMessages = conversations.flatMap { $0.messages }
        if let data = try? JSONEncoder().encode(allMessages) {
            userDefaults.set(data, forKey: UserDefaultsKeys.smsMessages)
        }
    }
    
    // MARK: - 从模块加载短信
    func loadMessagesFromModule() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let messages = try await atManager.readSMSList(status: "ALL")
            
            // 合并到现有会话
            for message in messages {
                addMessageToConversation(message)
            }
            
            saveCachedMessages()
            updateUnreadCount()
        } catch {
            print("[SMS] 加载短信失败: \(error)")
        }
    }
    
    // MARK: - 发送短信
    func sendSMS(phoneNumber: String, content: String) async throws {
        try await atManager.sendSMS(number: phoneNumber, content: content)
        
        // 添加到本地会话
        let message = SMSMessage(
            phoneNumber: phoneNumber,
            content: content,
            direction: .outgoing,
            isRead: true
        )
        addMessageToConversation(message)
        saveCachedMessages()
    }
    
    // MARK: - 处理收到的短信
    private func handleIncomingSMS(phoneNumber: String, content: String) {
        let isVerification = ATCommandParser.detectVerificationCode(in: content)
        
        let message = SMSMessage(
            phoneNumber: phoneNumber,
            content: content,
            direction: .incoming,
            isRead: false,
            isVerificationCode: isVerification
        )
        
        addMessageToConversation(message)
        saveCachedMessages()
        updateUnreadCount()
        
        // 发送通知
        showSMSNotification(phoneNumber: phoneNumber, content: content, isVerification: isVerification)
    }
    
    // MARK: - 显示通知
    private func showSMSNotification(phoneNumber: String, content: String, isVerification: Bool) {
        let content = UNMutableNotificationContent()
        content.title = isVerification ? "验证码短信" : "新短信"
        content.body = "\(phoneNumber.formattedPhoneNumber): \(content)"
        content.sound = .default
        content.badge = NSNumber(value: unreadCount + 1)
        
        if isVerification && userDefaults.bool(forKey: UserDefaultsKeys.smsVerificationPreview) {
            // 验证码短信可以显示完整内容
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - 标记已读
    func markAsRead(conversationId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        
        conversations[index].messages = conversations[index].messages.map { message in
            var mutableMessage = message
            // SMSMessage is a struct, so we need to create a new one
            return SMSMessage(
                id: message.id,
                phoneNumber: message.phoneNumber,
                content: message.content,
                timestamp: message.timestamp,
                direction: message.direction,
                isRead: true,
                isVerificationCode: message.isVerificationCode
            )
        }
        conversations[index].unreadCount = 0
        updateUnreadCount()
        saveCachedMessages()
    }
    
    // MARK: - 删除会话
    func deleteConversation(_ conversationId: String) {
        conversations.removeAll { $0.id == conversationId }
        saveCachedMessages()
        updateUnreadCount()
    }
    
    // MARK: - 删除单条消息
    func deleteMessage(_ messageId: UUID, conversationId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[index].messages.removeAll { $0.id == messageId }
        saveCachedMessages()
    }
    
    // MARK: - 辅助方法
    private func addMessageToConversation(_ message: SMSMessage) {
        if let index = conversations.firstIndex(where: { $0.id == message.phoneNumber }) {
            conversations[index].messages.append(message)
            if message.direction == .incoming && !message.isRead {
                conversations[index].unreadCount += 1
            }
        } else {
            let conversation = SMSConversation(
                phoneNumber: message.phoneNumber,
                messages: [message]
            )
            conversations.append(conversation)
        }
        
        // 按最新消息排序
        conversations.sort { ($0.latestMessage?.timestamp ?? .distantPast) > ($1.latestMessage?.timestamp ?? .distantPast) }
    }
    
    private func groupMessagesByPhoneNumber(_ messages: [SMSMessage]) -> [SMSConversation] {
        var grouped: [String: [SMSMessage]] = [:]
        
        for message in messages {
            grouped[message.phoneNumber, default: []].append(message)
        }
        
        return grouped.map { phoneNumber, messages in
            SMSConversation(phoneNumber: phoneNumber, messages: messages.sorted { $0.timestamp < $1.timestamp })
        }.sorted { ($0.latestMessage?.timestamp ?? .distantPast) > ($1.latestMessage?.timestamp ?? .distantPast) }
    }
    
    private func updateUnreadCount() {
        unreadCount = conversations.reduce(0) { $0 + $1.unreadCount }
    }
    
    // MARK: - 获取会话
    func conversation(for phoneNumber: String) -> SMSConversation? {
        conversations.first { $0.id == phoneNumber }
    }
}
