import Foundation
import Combine

// MARK: - 通讯录视图模型
final class ContactsViewModel: ObservableObject {
    
    // MARK: - 发布属性
    @Published var contacts: [Contact] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var selectedContact: Contact?
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined
    
    // MARK: - 服务引用
    private let contactManager = ContactManager.shared
    
    // MARK: - 取消包
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    init() {
        setupBindings()
    }
    
    // MARK: - 绑定
    private func setupBindings() {
        contactManager.$contacts
            .receive(on: DispatchQueue.main)
            .assign(to: &$contacts)
        
        contactManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        contactManager.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$authorizationStatus)
    }
    
    // MARK: - 筛选后的联系人
    var filteredContacts: [Contact] {
        contactManager.searchContacts(query: searchText)
    }
    
    // MARK: - 分组联系人
    var groupedContacts: [(String, [Contact])] {
        let filtered = filteredContacts
        let grouped = Dictionary(grouping: filtered) { contact in
            String(contact.displayName.prefix(1)).uppercased()
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    // MARK: - 请求权限
    func requestAuthorization() async {
        _ = await contactManager.requestAuthorization()
    }
    
    // MARK: - 刷新联系人
    func refreshContacts() {
        contactManager.loadContacts()
    }
    
    // MARK: - 选择联系人
    func selectContact(_ contact: Contact) {
        selectedContact = contact
    }
    
    // MARK: - 拨打电话
    func callContact(_ contact: Contact, phoneNumber: String) {
        CallManager.shared.dial(number: phoneNumber)
    }
    
    // MARK: - 发送短信
    func messageContact(_ contact: Contact, phoneNumber: String) {
        // 切换到短信页面并打开对应会话
        NotificationCenter.default.post(name: .init("OpenSMSConversation"), object: phoneNumber)
    }
    
    // MARK: - 添加联系人
    func addContact(firstName: String, lastName: String, phoneNumber: String) async {
        try? await contactManager.addContact(firstName: firstName, lastName: lastName, phoneNumber: phoneNumber)
    }
    
    // MARK: - 删除联系人
    func deleteContact(_ contact: Contact) {
        try? contactManager.deleteContact(contact)
    }
}
