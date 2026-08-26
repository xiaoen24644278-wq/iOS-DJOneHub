import Foundation
import Contacts

// MARK: - 联系人模型
struct Contact: Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let phoneNumbers: [PhoneNumber]
    let avatarData: Data?
    let organization: String?
    
    var displayName: String {
        let name = "\(lastName)\(firstName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? (organization ?? "未知联系人") : name
    }
    
    var initials: String {
        let first = lastName.first.map { String($0) } ?? ""
        let second = firstName.first.map { String($0) } ?? ""
        return (first + second).uppercased()
    }
    
    struct PhoneNumber: Hashable {
        let number: String
        let label: String
    }
    
    init(id: String,
         firstName: String = "",
         lastName: String = "",
         phoneNumbers: [PhoneNumber] = [],
         avatarData: Data? = nil,
         organization: String? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumbers = phoneNumbers
        self.avatarData = avatarData
        self.organization = organization
    }
}

// MARK: - 从 CNContact 转换
extension Contact {
    static func from(cnContact: CNContact) -> Contact {
        let phoneNumbers = cnContact.phoneNumbers.map { labeledValue in
            let number = labeledValue.value.stringValue
            let label = CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: labeledValue.label ?? "")
            return PhoneNumber(number: number, label: label)
        }
        return Contact(
            id: cnContact.identifier,
            firstName: cnContact.givenName,
            lastName: cnContact.familyName,
            phoneNumbers: phoneNumbers,
            avatarData: cnContact.thumbnailImageData,
            organization: cnContact.organizationName
        )
    }
}
