import SwiftUI

// MARK: - 设置主视图
struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @ObservedObject private var connection = ModuleConnectionManager.shared

    var body: some View {
        List {
            // 模块连接（v2：ECM 网卡 + 网关探测诊断）
            Section {
                NavigationLink {
                    ModuleConnectionDetailView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: connection.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 20))
                            .foregroundStyle(connection.isConnected ? Theme.success : Theme.danger)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(connection.isConnected ? "模块已连接 · \(connection.transport.rawValue)" : "模块未连接")
                                .font(Theme.Typo.headline)
                            Text(connectionSubtitle)
                                .font(Theme.Typo.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        SignalIndicator(bars: viewModel.moduleStatus.signalBars, isConnected: viewModel.moduleStatus.isConnected)
                    }
                    .padding(.vertical, 4)
                }
            }

            // 模块详细信息
            Section {
                NavigationLink {
                    ModuleStatusView(viewModel: viewModel)
                } label: {
                    NavigationRow(
                        title: "模块状态详情",
                        systemImage: "info.circle",
                        value: viewModel.moduleStatus.operatorName.isEmpty ? "-" : viewModel.moduleStatus.operatorName
                    )
                }
            }
            
            // 连接设置
            Section("连接设置") {
                ToggleRow(
                    title: "自动连接",
                    systemImage: "link.badge.plus",
                    isOn: $viewModel.autoConnect
                )
                
                NavigationLink {
                    ConnectionModeView(viewModel: viewModel)
                } label: {
                    NavigationRow(
                        title: "连接模式",
                        systemImage: "usb.ports.fill",
                        value: viewModel.connectionMode.displayName
                    )
                }
                
                NavigationLink {
                    ModuleDiscoveryView()
                } label: {
                    NavigationRow(
                        title: "手动扫描网关（旧）",
                        systemImage: "network",
                        value: NetworkCommunicationManager.shared.isConnected ? "已连接" : "未连接"
                    )
                }
            }
            
            // 网络设置
            Section("网络设置") {
                NavigationLink {
                    NetworkSettingsView(viewModel: viewModel)
                } label: {
                    NavigationRow(
                        title: "移动网络",
                        systemImage: "network",
                        value: viewModel.dataEnabled ? "已启用" : "已关闭"
                    )
                }
            }
            
            // 短信设置
            Section("短信设置") {
                ToggleRow(
                    title: "短信通知",
                    systemImage: "bell.badge",
                    isOn: $viewModel.smsNotificationEnabled
                )
                
                ToggleRow(
                    title: "验证码预览",
                    systemImage: "shield.checkered",
                    isOn: $viewModel.smsVerificationPreview,
                    subtitle: "在通知中显示验证码内容"
                )
                
                ToggleRow(
                    title: "自动清理旧短信",
                    systemImage: "trash",
                    isOn: $viewModel.smsAutoDelete,
                    subtitle: "读取后自动从模块删除"
                )
            }
            
            // 通话设置
            Section("通话设置") {
                ToggleRow(
                    title: "来电通知",
                    systemImage: "phone.arrow.down.left",
                    isOn: $viewModel.callNotificationEnabled
                )
                
                ToggleRow(
                    title: "自动接听",
                    systemImage: "phone.and.waveform",
                    isOn: $viewModel.autoAnswer,
                    subtitle: "来电后自动接听"
                )
                
                if viewModel.autoAnswer {
                    Stepper(value: $viewModel.autoAnswerDelay, in: 1...30, step: 1) {
                        HStack {
                            Text("自动接听延迟")
                            Spacer()
                            Text("\(Int(viewModel.autoAnswerDelay)) 秒")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                ToggleRow(
                    title: "默认扬声器",
                    systemImage: "speaker.wave.3.fill",
                    isOn: $viewModel.speakerDefault,
                    subtitle: "通话时默认开启扬声器"
                )
            }
            
            // 高级功能
            Section("高级功能") {
                NavigationLink {
                    eSIMManagerView(viewModel: viewModel)
                } label: {
                    NavigationRow(
                        title: "eSIM 管理",
                        systemImage: "simcard.fill"
                    )
                }
                
                NavigationLink {
                    GPSStatusView(viewModel: viewModel)
                } label: {
                    NavigationRow(
                        title: "GPS 定位",
                        systemImage: "location.fill",
                        value: viewModel.gpsStatus.isEnabled ? "已启用" : "已关闭"
                    )
                }
                
                NavigationLink {
                    ATConsoleView(viewModel: viewModel)
                } label: {
                    NavigationRow(
                        title: "AT 指令控制台",
                        systemImage: "terminal.fill"
                    )
                }
            }
            
            // 应用设置
            Section("应用") {
                Picker(selection: $viewModel.appTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                } label: {
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        Text("外观")
                    }
                }
                
                NavigationLink {
                    AboutView()
                } label: {
                    NavigationRow(
                        title: "关于",
                        systemImage: "info.circle.fill"
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            viewModel.saveSettings()
        }
    }

    private var connectionSubtitle: String {
        if connection.isConnected {
            var parts: [String] = []
            if let ip = connection.gatewayIP {
                parts.append("\(ip):\(connection.gatewayPort)")
            }
            if let ifName = connection.interfaceName {
                parts.append("接口 \(ifName)")
            }
            return parts.joined(separator: " · ")
        }
        if case .failed(let reason) = connection.phase {
            return reason
        }
        if connection.isProbing { return "正在通过 ECM 网卡探测模块网关…" }
        return "插入模块后 app 会自动检测"
    }
}

// MARK: - 模块连接详情（v2 诊断页）
struct ModuleConnectionDetailView: View {
    @ObservedObject private var connection = ModuleConnectionManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                // 连接状态卡
                MinimalCard {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        HStack(spacing: Theme.Space.s) {
                            StatusDot(state: connection.isConnected ? .ok : .bad)
                            Text(connection.isConnected ? "已连接" : "未连接")
                                .font(Theme.Typo.title)
                            Spacer()
                            Text(connection.transport.rawValue)
                                .font(Theme.Typo.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        row("通信方式", connection.transport.rawValue)
                        row("网关地址", connection.gatewayIP.map { "\($0):\(connection.gatewayPort)" } ?? "-")
                        row("网络接口", connection.interfaceName ?? "-")
                        row("本机地址", connection.localIP ?? "-")
                    }
                }

                // 操作
                PrimaryButton(title: connection.isProbing ? "正在检测…" : "重新检测模块") {
                    Task { await connection.rediscover() }
                }

                // 诊断提示
                MinimalCard {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text("无法识别模块时请检查")
                            .font(Theme.Typo.headline)
                        bullet("模块已通过数据线连接（Lightning/USB-C 需支持数据传输）")
                        bullet("iOS 设置中已允许该 USB 网络适配器（ECM 网卡）")
                        bullet("模块侧已刷入 DjiModemSuite 固件，提供 TCP/HTTP AT 桥接服务")
                        bullet("若走 HTTP 模式，保持 WebSocket 事件流可达以接收来电/新短信")
                    }
                }

                // 探测日志
                if !connection.lastProbeLog.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text("探测日志")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)
                        MinimalCard {
                            Text(connection.lastProbeLog.joined(separator: "\n"))
                                .font(Theme.Typo.mono)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(Theme.Space.m)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("模块连接")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(Theme.Typo.body).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(Theme.Typo.mono)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.s) {
            Text("·")
            Text(text)
                .font(Theme.Typo.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 连接模式选择
struct ConnectionModeView: View {
    @StateObject var viewModel: SettingsViewModel
    
    var body: some View {
        List {
            ForEach(ConnectionMode.allCases) { mode in
                Button {
                    Task {
                        await viewModel.setConnectionMode(mode)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.displayName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            Text(mode.description)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.connectionMode == mode {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("连接模式")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 预览
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView(viewModel: SettingsViewModel())
        }
    }
}
