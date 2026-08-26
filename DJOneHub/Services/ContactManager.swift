import Foundation
import Combine
import Contacts

// MARK: - 通讯录管理器
final class ContactManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = ContactManager()
    
    // MARK: - 发布属性
    @Published private(set) var contacts: [Contact] = []
    @Published private(set) var isLoading = false
    @Published private(set) var authorizationStatus: CNAuthorizationStatus = .notDetermined
    
    // MARK: - 私有属性
    private let contactStore = CNContactStore()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - 初始化
    private init() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        if authorizationStatus == .authorized {
            loadContacts()
        }
    }
    
    // MARK: - 请求权限
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            await MainActor.run {
                self.authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
            }
            if granted {
                loadContacts()
            }
            return granted
        } catch {
            print("[Contacts] 请求权限失败: \(error)")
            return false
        }
    }
    
    // MARK: - 加载联系人
    func loadContacts() {
        guard authorizationStatus == .authorized else { return }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let keys = [
                CNContactIdentifierKey,
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactPhoneNumbersKey,
                CNContactThumbnailImageDataKey,
                CNContactOrganizationNameKey
            ] as [CNKeyDescriptor]
            
            let request = CNContactFetchRequest(keysToFetch: keys)
            request.sortOrder = .familyName
            
            var loadedContacts: [Contact] = []
            
            do {
                try self.contactStore.enumerateContacts(with: request) { cnContact, _ in
                    let contact = Contact.from(cnContact: cnContact)
                    if !contact.phoneNumbers.isEmpty {
                        loadedContacts.append(contact)
                    }
                }
                
                // 按姓名排序
                loadedContacts.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                
                DispatchQueue.main.async {
                    self.contacts = loadedContacts
                    self.isLoading = false
                }
            } catch {
                print("[Contacts] 加载联系人失败: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - 搜索联系人
    func searchContacts(query: String) -> [Contact] {
        guard !query.isEmpty else { return contacts }
        
        let lowercasedQuery = query.lowercased()
        return contacts.filter { contact in
            contact.displayName.lowercased().contains(lowercasedQuery) ||
            contact.phoneNumbers.contains { $0.number.contains(query) }
        }
    }
    
    // MARK: - 根据号码查找联系人
    func contact(forPhoneNumber phoneNumber: String) -> Contact? {
        contacts.first { contact in
            contact.phoneNumbers.contains { $0.number.matchesPhoneNumber(phoneNumber) }
        }
    }
    
    // MARK: - 获取联系人姓名
    func displayName(forPhoneNumber phoneNumber: String) -> String {
        contact(forPhoneNumber: phoneNumber)?.displayName ?? phoneNumber.formattedPhoneNumber
    }
    
    // MARK: - 分组联系人（按首字母）
    var groupedContacts: [(String, [Contact])] {
        let grouped = Dictionary(grouping: contacts) { contact in
            String(contact.displayName.prefix(1)).uppercased()
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    // MARK: - 添加联系人
    func addContact(firstName: String, lastName: String, phoneNumber: String, label: String = "手机") async throws {
        let cnContact = CNMutableContact()
        cnContact.givenName = firstName
        cnContact.familyName = lastName
        cnContact.phoneNumbers = [CNLabeledValue(label: label, value: CNPhoneNumber(stringValue: phoneNumber))]
        
        let saveRequest = CNSaveRequest()
        saveRequest.add(cnContact, toContainerWithIdentifier: nil)
        
        try contactStore.execute(saveRequest)
        loadContacts()
    }
    
    // MARK: - 删除联系人
    func deleteContact(_ contact: Contact) throws {
        guard let cnContact = try contactStore.unifiedContact(withIdentifier: contact.id, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]) as? CNMutableContact else {
            return
        }
        
        let saveRequest = CNSaveRequest()
        saveRequest.delete(cnContact)
        try contactStore.execute(saveRequest)
        
        contacts.removeAll { $0.id == contact.id }
    }
}
