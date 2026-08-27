import SwiftUI

// MARK: - 主标签视图
struct MainTabView: View {
    @StateObject private var phoneViewModel = PhoneViewModel()
    @StateObject private var smsViewModel = SMSViewModel()
    @StateObject private var contactsViewModel = ContactsViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    @State private var selectedTab: Tab = .phone
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    enum Tab: String, CaseIterable {
        case phone = "电话"
        case sms = "短信"
        case contacts = "通讯录"
        case settings = "设置"
        
        var systemImage: String {
            switch self {
            case .phone: return "phone.fill"
            case .sms: return "message.fill"
            case .contacts: return "person.2.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        Group {
            if isPadLandscape {
                // iPad 横屏：侧边栏布局
                NavigationSplitView {
                    sidebarContent
                } detail: {
                    detailContent
                }
            } else {
                // iPhone 或 iPad 竖屏：标签栏布局
                TabView(selection: $selectedTab) {
                    tabContent
                }
            }
        }
        .overlay(alignment: .top) {
            // 顶部状态栏
            StatusBar(
                moduleStatus: settingsViewModel.moduleStatus,
                networkStatus: settingsViewModel.networkStatus
            )
            .offset(y: -8)
        }
        .onAppear {
            // 初始化服务
            if settingsViewModel.contactsSyncEnabled {
                Task {
                    await contactsViewModel.requestAuthorization()
                }
            }
        }
    }
    
    // MARK: - iPad 横屏侧边栏
    private var sidebarContent: some View {
        List(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Label(tab.rawValue, systemImage: tab.systemImage)
                    .tag(tab)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("DJOneHub")
    }
    
    // MARK: - iPad 横屏详情页
    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .phone:
            PhoneView(viewModel: phoneViewModel)
        case .sms:
            SMSView(viewModel: smsViewModel)
        case .contacts:
            ContactsView(viewModel: contactsViewModel)
        case .settings:
            SettingsView(viewModel: settingsViewModel)
        }
    }
    
    // MARK: - iPhone/iPad 竖屏标签页
    @ViewBuilder
    private var tabContent: some View {
        NavigationStack {
            PhoneView(viewModel: phoneViewModel)
        }
        .tabItem {
            Label("电话", systemImage: "phone.fill")
        }
        .tag(Tab.phone)
        
        NavigationStack {
            SMSView(viewModel: smsViewModel)
        }
        .tabItem {
            Label("短信", systemImage: "message.fill")
        }
        .badge(smsViewModel.unreadCount)
        .tag(Tab.sms)
        
        NavigationStack {
            ContactsView(viewModel: contactsViewModel)
        }
        .tabItem {
            Label("通讯录", systemImage: "person.2.fill")
        }
        .tag(Tab.contacts)
        
        NavigationStack {
            SettingsView(viewModel: settingsViewModel)
        }
        .tabItem {
            Label("设置", systemImage: "gearshape.fill")
        }
        .tag(Tab.settings)
    }
    
    // MARK: - 判断是否为 iPad 横屏
    private var isPadLandscape: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && 
        horizontalSizeClass == .regular
    }
}

// MARK: - 预览
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
