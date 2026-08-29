import SwiftUI

// MARK: - 主界面（极简风格 v2）
/// 布局策略：
/// - regular 宽度（iPad 横竖屏 / 大屏 iPhone 横屏）：NavigationSplitView 侧栏
/// - compact 宽度（iPhone 竖屏）：TabView 底部标签
/// 依据 horizontalSizeClass 实时切换，旋转 / 分屏自动过渡
struct MainTabView: View {
    @StateObject private var phoneViewModel = PhoneViewModel()
    @StateObject private var smsViewModel = SMSViewModel()
    @StateObject private var contactsViewModel = ContactsViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @ObservedObject private var connection = ModuleConnectionManager.shared

    @State private var selectedTab: Tab = .phone
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    enum Tab: String, CaseIterable, Hashable {
        case phone = "电话"
        case sms = "短信"
        case contacts = "通讯录"
        case settings = "设置"

        var systemImage: String {
            switch self {
            case .phone: return "phone"
            case .sms: return "message"
            case .contacts: return "person.2"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                splitLayout
            } else {
                tabLayout
            }
        }
        .tint(Theme.accent)
        .safeAreaInset(edge: .top, spacing: 0) {
            SlimStatusBar(
                moduleStatus: settingsViewModel.moduleStatus,
                connection: connection
            )
        }
        .task {
            // 启动即通过 ECM 网卡自动探测模块（v2 关键修复）
            await connection.autoConnect(reason: "应用启动")
            if settingsViewModel.contactsSyncEnabled {
                await contactsViewModel.requestAuthorization()
            }
        }
    }

    // MARK: - 侧栏布局（iPad / 横屏）
    private var splitLayout: some View {
        NavigationSplitView {
            SidebarList(selectedTab: $selectedTab)
                .listStyle(.sidebar)
                .navigationTitle("DJOneHub")
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            detailContent
                .id(selectedTab)
        }
    }

    // MARK: - 标签布局（iPhone 竖屏 / iPad compact）
    private var tabLayout: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PhoneView(viewModel: phoneViewModel)
            }
            .tabItem { Label("电话", systemImage: "phone") }
            .tag(Tab.phone)

            NavigationStack {
                SMSView(viewModel: smsViewModel)
            }
            .tabItem { Label("短信", systemImage: "message") }
            .badge(smsViewModel.unreadCount)
            .tag(Tab.sms)

            NavigationStack {
                ContactsView(viewModel: contactsViewModel)
            }
            .tabItem { Label("通讯录", systemImage: "person.2") }
            .tag(Tab.contacts)

            NavigationStack {
                SettingsView(viewModel: settingsViewModel)
            }
            .tabItem { Label("设置", systemImage: "gearshape") }
            .tag(Tab.settings)
        }
    }

    // MARK: - 详情内容
    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .phone:
            NavigationStack { PhoneView(viewModel: phoneViewModel) }
        case .sms:
            NavigationStack { SMSView(viewModel: smsViewModel) }
        case .contacts:
            NavigationStack { ContactsView(viewModel: contactsViewModel) }
        case .settings:
            NavigationStack { SettingsView(viewModel: settingsViewModel) }
        }
    }
}

// MARK: - 侧栏列表（独立子视图，避免类型推断超时）
private struct SidebarList: View {
    @Binding var selectedTab: MainTabView.Tab

    var body: some View {
        List(selection: $selectedTab) {
            Section {
                ForEach(MainTabView.Tab.allCases, id: \.self) { tab in
                    SidebarRow(tab: tab, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
            }
        }
    }
}

// MARK: - 侧栏行
private struct SidebarRow: View {
    let tab: MainTabView.Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            rowContent
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Theme.accent.opacity(0.10) : Color.clear)
    }

    private var rowContent: some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: tab.systemImage)
                .frame(width: 24)
                .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
            Text(tab.rawValue)
                .font(Theme.Typo.body)
                .foregroundStyle(isSelected ? Theme.accent : Color.primary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(Theme.Typo.caption)
                    .foregroundStyle(Theme.accent)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - 极简顶部状态栏
struct SlimStatusBar: View {
    let moduleStatus: ModuleStatus
    @ObservedObject var connection: ModuleConnectionManager

    private var dotState: StatusDot.State {
        if connection.isConnected { return .ok }
        switch connection.phase {
        case .connected: return .ok
        case .probingGateways, .detectingInterface, .connecting: return .warn
        case .failed: return .bad
        default: return .idle
        }
    }

    private var connectionText: String {
        if connection.isConnected {
            return connection.transport.rawValue
        }
        switch connection.phase {
        case .probingGateways, .detectingInterface, .connecting:
            return "检测模块…"
        case .failed:
            return "未检测到模块"
        default:
            return "未连接"
        }
    }

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            HStack(spacing: Theme.Space.s) {
                StatusDot(state: dotState)
                Text(connectionText)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Theme.Space.m)

            if connection.isConnected, let ip = connection.gatewayIP {
                Text(ip)
                    .font(Theme.Typo.mono)
                    .foregroundStyle(.tertiary)
            }

            if !moduleStatus.operatorName.isEmpty && moduleStatus.operatorName != "-" {
                Text(moduleStatus.operatorName)
                    .font(Theme.Typo.caption)
                    .foregroundStyle(.secondary)
            }

            NetworkIndicator(
                networkType: moduleStatus.networkType,
                isConnected: moduleStatus.isConnected
            )

            SignalIndicator(
                bars: moduleStatus.signalBars,
                isConnected: moduleStatus.isConnected
            )
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }
}

#Preview {
    MainTabView()
}
