import SwiftUI

// MARK: - 设置主视图
struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    
    var body: some View {
        List {
            // 模块状态卡片
            Section {
                NavigationLink {
                    ModuleStatusView(viewModel: viewModel)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(viewModel.moduleStatus.isConnected ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: viewModel.moduleStatus.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                .foregroundColor(viewModel.moduleStatus.isConnected ? .green : .red)
                                .font(.system(size: 20))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.moduleStatus.isConnected ? "模块已连接" : "模块未连接")
                                .font(.system(size: 16, weight: .medium))
                            Text(viewModel.moduleStatus.operatorName.isEmpty ? "等待连接大疆4G模块" : viewModel.moduleStatus.operatorName)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        SignalIndicator(bars: viewModel.moduleStatus.signalBars, isConnected: viewModel.moduleStatus.isConnected)
                    }
                    .padding(.vertical, 4)
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
