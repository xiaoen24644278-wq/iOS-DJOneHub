import SwiftUI

// MARK: - AT 指令控制台
struct ATConsoleView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var commandInput = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 命令历史/响应区域
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.atCommandHistory) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                // 发送的命令
                                HStack(alignment: .top) {
                                    Text(">")
                                        .foregroundColor(.accentColor)
                                        .font(.system(.body, design: .monospaced))
                                    Text(record.command)
                                        .foregroundColor(.primary)
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                // 响应
                                Text(record.response)
                                    .foregroundColor(record.success ? .secondary : .red)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.leading, 16)
                            }
                            .id(record.id)
                        }
                        
                        if viewModel.atCommandHistory.isEmpty {
                            ContentUnavailableView(
                                "AT 指令控制台",
                                systemImage: "terminal.fill",
                                description: Text("输入 AT 指令与模块直接通信\n例如: AT, AT+CSQ, AT+COPS?")
                            )
                            .padding(.top, 60)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.atCommandHistory.count) { _ in
                    if let last = viewModel.atCommandHistory.first {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // 输入栏
            HStack(spacing: 8) {
                TextField("输入 AT 指令", text: $commandInput)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit {
                        executeCommand()
                    }
                
                Button {
                    executeCommand()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(commandInput.isEmpty ? Color.gray : Color.accentColor)
                        .cornerRadius(8)
                }
                .disabled(commandInput.isEmpty || viewModel.isAtExecuting)
            }
            .padding()
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator)),
                alignment: .top
            )
        }
        .navigationTitle("AT 控制台")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(id: "atconsoleview") {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        commandInput = "AT"
                    } label: {
                        Label("AT (测试)", systemImage: "circle")
                    }
                    Button {
                        commandInput = "AT+CSQ"
                    } label: {
                        Label("AT+CSQ (信号)", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    Button {
                        commandInput = "AT+COPS?"
                    } label: {
                        Label("AT+COPS? (运营商)", systemImage: "network")
                    }
                    Button {
                        commandInput = "AT+CPIN?"
                    } label: {
                        Label("AT+CPIN? (SIM状态)", systemImage: "simcard")
                    }
                    Button {
                        commandInput = "AT+CGSN"
                    } label: {
                        Label("AT+CGSN (IMEI)", systemImage: "number")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private func executeCommand() {
        guard !commandInput.isEmpty else { return }
        viewModel.atCommandInput = commandInput
        commandInput = ""
        
        Task {
            await viewModel.executeATCommand()
        }
    }
}

// MARK: - eSIM 管理视图
struct eSIMManagerView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var showingAddProfile = false
    
    var body: some View {
        List {
            // eUICC 信息
            Section("eUICC 信息") {
                InfoRow(title: "EID", value: viewModel.eSIMStatus.eid)
                InfoRow(title: "固件版本", value: viewModel.eSIMStatus.firmwareVersion)
                InfoRow(title: "可用空间", value: ByteCountFormatter.string(fromByteCount: Int64(viewModel.eSIMStatus.freeSpace), countStyle: .binary))
                InfoRow(title: "总空间", value: ByteCountFormatter.string(fromByteCount: Int64(viewModel.eSIMStatus.totalSpace), countStyle: .binary))
            }
            
            // Profile 列表
            Section("已安装 Profile") {
                if viewModel.eSIMStatus.profiles.isEmpty {
                    ContentUnavailableView(
                        "暂无 Profile",
                        systemImage: "simcard",
                        description: Text("点击右上角添加 eSIM Profile")
                    )
                } else {
                    ForEach(viewModel.eSIMStatus.profiles) { profile in
                        eSIMProfileRow(profile: profile, viewModel: viewModel)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("eSIM 管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(id: "atconsoleview") {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddProfile = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddProfile) {
            AddeSIMProfileView(viewModel: viewModel)
        }
        .onAppear {
            Task {
                await viewModel.refresheSIMInfo()
            }
        }
        .refreshable {
            Task {
                await viewModel.refresheSIMInfo()
            }
        }
    }
}

// MARK: - eSIM Profile 行
struct eSIMProfileRow: View {
    let profile: eSIMStatus.eSIMProfile
    @StateObject var viewModel: SettingsViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name.isEmpty ? profile.iccid : profile.name)
                    .font(.system(size: 16, weight: .medium))
                Text(profile.providerName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text(profile.iccid)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 状态
            HStack(spacing: 4) {
                Circle()
                    .fill(profile.isEnabled ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text(profile.isEnabled ? "启用" : "禁用")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Menu {
                if profile.isEnabled {
                    Button {
                        Task {
                            await viewModel.disableProfile(iccid: profile.iccid)
                        }
                    } label: {
                        Label("禁用", systemImage: "pause.circle")
                    }
                } else {
                    Button {
                        Task {
                            await viewModel.enableProfile(iccid: profile.iccid)
                        }
                    } label: {
                        Label("启用", systemImage: "play.circle")
                    }
                }
                
                Button(role: .destructive) {
                    Task {
                        await viewModel.deleteProfile(iccid: profile.iccid)
                    }
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 添加 eSIM Profile
struct AddeSIMProfileView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var activationCode = ""
    @State private var confirmationCode = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("激活码") {
                    TextField("输入 LPA:1$激活码", text: $activationCode)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("确认码（可选）") {
                    TextField("输入确认码", text: $confirmationCode)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Button {
                        Task {
                            try? await eSIMManager.shared.downloadProfile(
                                activationCode: activationCode,
                                confirmationCode: confirmationCode.isEmpty ? nil : confirmationCode
                            )
                            await viewModel.refresheSIMInfo()
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.eSIMManager.isProcessing {
                                ProgressView()
                            }
                            Text("下载 Profile")
                                .foregroundColor(.accentColor)
                            Spacer()
                        }
                    }
                    .disabled(activationCode.isEmpty || viewModel.eSIMManager.isProcessing)
                }
            }
            .navigationTitle("添加 eSIM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(id: "atconsoleview") {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 预览
struct ATConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ATConsoleView(viewModel: SettingsViewModel())
        }
    }
}
