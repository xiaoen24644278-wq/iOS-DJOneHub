import SwiftUI

// MARK: - 短信主视图
struct SMSView: View {
    @StateObject var viewModel: SMSViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        Group {
            if isPadRegular {
                // iPad 横屏/大屏：分栏布局
                NavigationSplitView {
                    SMSListView(viewModel: viewModel)
                } detail: {
                    if let conversationId = viewModel.selectedConversationId,
                       let conversation = viewModel.conversation(for: conversationId) {
                        SMSConversationView(viewModel: viewModel, conversation: conversation)
                    } else {
                        ContentUnavailableView(
                            "选择对话",
                            systemImage: "message.fill",
                            description: Text("从左侧选择一个对话开始查看短信")
                        )
                    }
                }
            } else {
                // iPhone/iPad 竖屏：导航栈布局
                NavigationStack {
                    SMSListView(viewModel: viewModel)
                        .navigationDestination(for: String.self) { conversationId in
                            if let conversation = viewModel.conversation(for: conversationId) {
                                SMSConversationView(viewModel: viewModel, conversation: conversation)
                            }
                        }
                }
            }
        }
        .navigationTitle("短信")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await viewModel.loadFromModule()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
    }
    
    private var isPadRegular: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }
}

// MARK: - 短信会话列表
struct SMSListView: View {
    @StateObject var viewModel: SMSViewModel
    @State private var showingNewMessage = false
    
    var body: some View {
        List {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索", text: $viewModel.searchText)
            }
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .listRowSeparator(.hidden)
            
            if viewModel.filteredConversations.isEmpty {
                ContentUnavailableView(
                    "暂无短信",
                    systemImage: "message.fill",
                    description: Text("收到的短信将显示在这里")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.filteredConversations) { conversation in
                    SMSConversationRow(conversation: conversation, viewModel: viewModel)
                }
                .onDelete(perform: deleteConversations)
            }
        }
        .listStyle(.plain)
        .refreshable {
            Task {
                await viewModel.loadFromModule()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingNewMessage = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingNewMessage) {
            SMSComposeView(viewModel: viewModel)
        }
    }
    
    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteConversation(viewModel.filteredConversations[index].id)
        }
    }
}

// MARK: - 短信会话行
struct SMSConversationRow: View {
    let conversation: SMSConversation
    @StateObject var viewModel: SMSViewModel
    
    var body: some View {
        Button {
            viewModel.selectConversation(conversation.id)
        } label: {
            HStack(spacing: 12) {
                // 头像
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Text(contactInitials)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                
                // 内容
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                        if let timestamp = conversation.latestMessage?.timestamp {
                            Text(timestamp.shortTimeDescription)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text(conversation.latestMessage?.content ?? "")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if conversation.unreadCount > 0 {
                            Text("\(conversation.unreadCount)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowBackground(viewModel.selectedConversationId == conversation.id ? Color.accentColor.opacity(0.1) : Color.clear)
    }
    
    private var displayName: String {
        conversation.contactName ?? viewModel.contactName(for: conversation.phoneNumber)
    }
    
    private var contactInitials: String {
        let name = displayName
        if name.count <= 2 {
            return name
        }
        return String(name.prefix(1))
    }
}

// MARK: - 短信对话视图
struct SMSConversationView: View {
    @StateObject var viewModel: SMSViewModel
    let conversation: SMSConversation
    @State private var scrollToBottom = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(conversation.messages) { message in
                            SMSMessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                }
                .onChange(of: conversation.messages.count) { _ in
                    if let lastMessage = conversation.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = conversation.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            
            // 输入栏
            SMSInputBar(viewModel: viewModel)
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var displayName: String {
        conversation.contactName ?? viewModel.contactName(for: conversation.phoneNumber)
    }
}

// MARK: - 短信气泡
struct SMSMessageBubble: View {
    let message: SMSMessage
    
    var body: some View {
        HStack {
            if message.direction == .outgoing {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.direction == .outgoing ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(message.direction == .outgoing ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.direction == .outgoing ? Color.accentColor : Color(.secondarySystemBackground))
                    )
                
                Text(message.timestamp.shortTimeDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if message.direction == .incoming {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - 短信输入栏
struct SMSInputBar: View {
    @StateObject var viewModel: SMSViewModel
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("输入短信内容", text: $viewModel.draftMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .focused($isInputFocused)
                .lineLimit(1...4)
            
            Button {
                Task {
                    await viewModel.sendMessage()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .accentColor)
            }
            .disabled(viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
}

// MARK: - 新建短信视图
struct SMSComposeView: View {
    @StateObject var viewModel: SMSViewModel
    @State private var recipient = ""
    @State private var content = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 收件人
                HStack {
                    Text("收件人")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)
                    TextField("输入手机号", text: $recipient)
                        .textFieldStyle(.plain)
                        .keyboardType(.phonePad)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                // 内容
                TextEditor(text: $content)
                    .padding()
                    .font(.system(size: 16))
            }
            .navigationTitle("新建短信")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("发送") {
                        Task {
                            await viewModel.sendMessage(to: recipient, content: content)
                            dismiss()
                        }
                    }
                    .disabled(recipient.isEmpty || content.isEmpty)
                }
            }
        }
    }
}

// MARK: - 预览
struct SMSView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SMSView(viewModel: SMSViewModel())
        }
    }
}
