import Foundation
import Combine

// MARK: - 短信视图模型
final class SMSViewModel: ObservableObject {
    
    // MARK: - 发布属性
    @Published var conversations: [SMSConversation] = []
    @Published var selectedConversationId: String?
    @Published var draftMessage = ""
    @Published var isLoading = false
    @Published var unreadCount = 0
    @Published var searchText = ""
    
    // MARK: - 服务引用
    private let smsManager = SMSManager.shared
    private let contactManager = ContactManager.shared
    
    // MARK: - 取消包
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    init() {
        setupBindings()
    }
    
    // MARK: - 绑定
    private func setupBindings() {
        smsManager.$conversations
            .receive(on: DispatchQueue.main)
            .assign(to: &$conversations)
        
        smsManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        smsManager.$unreadCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$unreadCount)
    }
    
    // MARK: - 筛选后的会话
    var filteredConversations: [SMSConversation] {
        guard !searchText.isEmpty else { return conversations }
        
        let lowercasedQuery = searchText.lowercased()
        return conversations.filter { conversation in
            conversation.phoneNumber.lowercased().contains(lowercasedQuery) ||
            (conversation.contactName?.lowercased().contains(lowercasedQuery) ?? false) ||
            conversation.messages.contains { $0.content.lowercased().contains(lowercasedQuery) }
        }
    }
    
    // MARK: - 获取会话
    func conversation(for id: String) -> SMSConversation? {
        conversations.first { $0.id == id }
    }
    
    // MARK: - 选择会话
    func selectConversation(_ id: String) {
        selectedConversationId = id
        smsManager.markAsRead(conversationId: id)
    }
    
    // MARK: - 发送短信
    func sendMessage() async {
        guard let conversationId = selectedConversationId,
              !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let content = draftMessage
        draftMessage = ""
        
        do {
            try await smsManager.sendSMS(phoneNumber: conversationId, content: content)
        } catch {
            print("[SMS] 发送失败: \(error)")
            draftMessage = content
        }
    }
    
    // MARK: - 发送到新号码
    func sendMessage(to phoneNumber: String, content: String) async {
        do {
            try await smsManager.sendSMS(phoneNumber: phoneNumber, content: content)
            selectedConversationId = phoneNumber
        } catch {
            print("[SMS] 发送失败: \(error)")
        }
    }
    
    // MARK: - 从模块加载
    func loadFromModule() async {
        await smsManager.loadMessagesFromModule()
    }
    
    // MARK: - 删除会话
    func deleteConversation(_ id: String) {
        smsManager.deleteConversation(id)
        if selectedConversationId == id {
            selectedConversationId = nil
        }
    }
    
    // MARK: - 删除消息
    func deleteMessage(_ messageId: UUID, conversationId: String) {
        smsManager.deleteMessage(messageId, conversationId: conversationId)
    }
    
    // MARK: - 辅助方法
    func contactName(for number: String) -> String {
        contactManager.displayName(forPhoneNumber: number)
    }
}
