import SwiftUI

// MARK: - 通讯录主视图
struct ContactsView: View {
    @StateObject var viewModel: ContactsViewModel
    @State private var showingAddContact = false
    
    var body: some View {
        Group {
            if viewModel.authorizationStatus == .authorized || viewModel.authorizationStatus == .notDetermined {
                List {
                    // 搜索框
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("搜索联系人", text: $viewModel.searchText)
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .listRowSeparator(.hidden)
                    
                    if viewModel.authorizationStatus == .notDetermined {
                        Section {
                            Button {
                                Task {
                                    await viewModel.requestAuthorization()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .foregroundColor(.accentColor)
                                    Text("访问通讯录")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else if viewModel.filteredContacts.isEmpty {
                        ContentUnavailableView(
                            "暂无联系人",
                            systemImage: "person.2.fill",
                            description: Text("授权访问通讯录后，联系人将显示在这里")
                        )
                        .listRowSeparator(.hidden)
                    } else {
                        // 分组联系人
                        ForEach(viewModel.groupedContacts, id: \.0) { section in
                            Section(header: Text(section.0)) {
                                ForEach(section.1) { contact in
                                    ContactRow(contact: contact, viewModel: viewModel)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .navigationTitle("通讯录")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(id: "contactsview") {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAddContact = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddContact) {
                    AddContactView(viewModel: viewModel)
                }
                .refreshable {
                    viewModel.refreshContacts()
                }
            } else {
                // 权限被拒绝
                ContentUnavailableView {
                    Label("无法访问通讯录", systemImage: "person.2.slash")
                } description: {
                    Text("请在系统设置中允许 DJOneHub 访问通讯录")
                } actions: {
                    Button("打开设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

// MARK: - 联系人行
struct ContactRow: View {
    let contact: Contact
    @StateObject var viewModel: ContactsViewModel
    
    var body: some View {
        NavigationLink {
            ContactDetailView(contact: contact, viewModel: viewModel)
        } label: {
            HStack(spacing: 12) {
                // 头像
                if let avatarData = contact.avatarData, let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Text(contact.initials)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.displayName)
                        .font(.system(size: 16, weight: .medium))
                    if let firstPhone = contact.phoneNumbers.first {
                        Text(firstPhone.number.formattedPhoneNumber)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - 联系人详情
struct ContactDetailView: View {
    let contact: Contact
    @StateObject var viewModel: ContactsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            // 头部信息
            Section {
                VStack(spacing: 12) {
                    if let avatarData = contact.avatarData, let uiImage = UIImage(data: avatarData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Text(contact.initials)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    Text(contact.displayName)
                        .font(.system(size: 22, weight: .semibold))
                    
                    if let organization = contact.organization, !organization.isEmpty {
                        Text(organization)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .listRowBackground(Color.clear)
            
            // 电话号码
            Section("电话号码") {
                ForEach(contact.phoneNumbers, id: \.number) { phone in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(phone.label)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(phone.number.formattedPhoneNumber)
                                .font(.system(size: 16))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button {
                                viewModel.callContact(contact, phoneNumber: phone.number)
                            } label: {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.green)
                                    .frame(width: 36, height: 36)
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            
                            Button {
                                viewModel.messageContact(contact, phoneNumber: phone.number)
                            } label: {
                                Image(systemName: "message.fill")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 36, height: 36)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // 删除联系人
            Section {
                Button(role: .destructive) {
                    viewModel.deleteContact(contact)
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text("删除联系人")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 添加联系人
struct AddContactView: View {
    @StateObject var viewModel: ContactsViewModel
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("姓名") {
                    TextField("姓", text: $lastName)
                    TextField("名", text: $firstName)
                }
                
                Section("电话号码") {
                    TextField("手机号码", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("新建联系人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(id: "contactsview") {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await viewModel.addContact(
                                firstName: firstName,
                                lastName: lastName,
                                phoneNumber: phoneNumber
                            )
                            dismiss()
                        }
                    }
                    .disabled(phoneNumber.isEmpty)
                }
            }
        }
    }
}

// MARK: - 预览
struct ContactsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ContactsView(viewModel: ContactsViewModel())
        }
    }
}
