import SwiftUI

// MARK: - 模块状态视图
struct ModuleStatusView: View {
    @StateObject var viewModel: SettingsViewModel
    
    var body: some View {
        List {
            // 连接状态
            Section {
                HStack {
                    Text("连接状态")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.moduleStatus.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(viewModel.moduleStatus.isConnected ? "已连接" : "未连接")
                            .foregroundColor(.secondary)
                    }
                }
                
                InfoRow(title: "设备名称", value: viewModel.moduleStatus.deviceName)
                InfoRow(title: "固件版本", value: viewModel.moduleStatus.firmwareVersion)
            }
            
            // SIM 信息
            Section("SIM 卡信息") {
                InfoRow(title: "SIM 状态", value: viewModel.moduleStatus.simStatus.rawValue)
                InfoRow(title: "IMSI", value: viewModel.moduleStatus.imsi)
                InfoRow(title: "ICCID", value: viewModel.moduleStatus.iccid)
            }
            
            // 设备信息
            Section("设备信息") {
                InfoRow(title: "IMEI", value: viewModel.moduleStatus.imei)
            }
            
            // 网络信息
            Section("网络信息") {
                InfoRow(title: "运营商", value: viewModel.moduleStatus.operatorName)
                InfoRow(title: "网络类型", value: viewModel.moduleStatus.networkType.rawValue)
                InfoRow(title: "信号强度", value: "\(viewModel.moduleStatus.signalStrength) / 31")
                InfoRow(title: "注册状态", value: registrationStatusText)
            }
            
            // 刷新按钮
            Section {
                Button {
                    Task {
                        await viewModel.refreshModuleStatus()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.moduleStatus.isConnected {
                            ProgressView()
                                .opacity(viewModel.isAtExecuting ? 1 : 0)
                        }
                        Text("刷新状态")
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                }
                .disabled(!viewModel.moduleStatus.isConnected)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("模块状态")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel.moduleStatus.isConnected {
                Task {
                    await viewModel.refreshModuleStatus()
                }
            }
        }
    }
    
    private var registrationStatusText: String {
        switch viewModel.moduleStatus.registrationStatus {
        case .notRegistered: return "未注册"
        case .registeredHome: return "已注册（本地）"
        case .searching: return "搜索中"
        case .registrationDenied: return "注册被拒绝"
        case .unknown: return "未知"
        case .registeredRoaming: return "已注册（漫游）"
        }
    }
}

// MARK: - 信息行
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - 网络设置视图
struct NetworkSettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var showingDiagnostics = false
    
    var body: some View {
        List {
            // 数据开关
            Section {
                ToggleRow(
                    title: "移动数据",
                    systemImage: "antenna.radiowaves.left.and.right",
                    isOn: Binding(
                        get: { viewModel.dataEnabled },
                        set: { viewModel.setDataEnabled($0) }
                    )
                )
                
                ToggleRow(
                    title: "数据漫游",
                    systemImage: "globe",
                    isOn: $viewModel.roamingEnabled,
                    subtitle: "在国外使用移动数据"
                )
            }
            
            // 网络模式
            Section("网络模式") {
                Picker(selection: $viewModel.networkMode) {
                    ForEach(NetworkStatus.NetworkMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                } label: {
                    Text("首选网络类型")
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.networkMode) { newValue in
                    viewModel.setNetworkMode(newValue)
                }
            }
            
            // APN 设置
            Section("APN 设置") {
                HStack {
                    Text("APN")
                    TextField("输入 APN", text: $viewModel.apn)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            viewModel.setAPN(viewModel.apn)
                        }
                }
            }
            
            // 网络状态
            Section("当前状态") {
                InfoRow(title: "接口类型", value: viewModel.networkStatus.interfaceType.rawValue)
                InfoRow(title: "IP 地址", value: viewModel.networkStatus.ipAddress ?? "-")
                InfoRow(title: "信号强度", value: "\(viewModel.networkStatus.signalStrength)")
            }
            
            // 流量统计
            Section("流量统计") {
                InfoRow(title: "本次发送", value: viewModel.trafficStats.sessionSentString)
                InfoRow(title: "本次接收", value: viewModel.trafficStats.sessionReceivedString)
                InfoRow(title: "总计发送", value: viewModel.trafficStats.totalSentString)
                InfoRow(title: "总计接收", value: viewModel.trafficStats.totalReceivedString)
            }
            
            // 诊断
            Section {
                Button {
                    showingDiagnostics = true
                } label: {
                    HStack {
                        Image(systemName: "stethoscope")
                            .foregroundColor(.accentColor)
                        Text("网络诊断")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("移动网络")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDiagnostics) {
            NetworkDiagnosticsView(viewModel: viewModel)
        }
    }
}

// MARK: - 网络诊断视图
struct NetworkDiagnosticsView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var results: [String: String] = [:]
    @State private var isRunning = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if isRunning {
                    Section {
                        HStack {
                            ProgressView()
                            Text("正在诊断...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                ForEach(Array(results.keys), id: \.self) { key in
                    Section(key) {
                        Text(results[key] ?? "")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("网络诊断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("重新诊断") {
                        runDiagnostics()
                    }
                    .disabled(isRunning)
                }
            }
            .onAppear {
                runDiagnostics()
            }
        }
    }
    
    private func runDiagnostics() {
        isRunning = true
        results.removeAll()
        
        Task {
            let diagResults = await viewModel.runNetworkDiagnostics()
            await MainActor.run {
                self.results = diagResults
                self.isRunning = false
            }
        }
    }
}

// MARK: - 预览
struct ModuleStatusView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ModuleStatusView(viewModel: SettingsViewModel())
        }
    }
}
