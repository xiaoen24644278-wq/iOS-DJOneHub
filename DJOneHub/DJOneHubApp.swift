import SwiftUI
import UserNotifications

// MARK: - 应用入口
@main
struct DJOneHubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(colorScheme)
                .onAppear {
                    // 配置应用外观
                    configureAppearance()
                    
                    // 请求通知权限
                    requestNotificationPermissions()
                }
        }
    }
    
    // MARK: - 颜色方案
    private var colorScheme: ColorScheme? {
        switch settingsViewModel.appTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    // MARK: - 配置外观
    private func configureAppearance() {
        // 配置导航栏外观
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        
        // 配置 TabBar 外观
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // 配置列表外观
        UITableView.appearance().backgroundColor = .systemBackground
    }
    
    // MARK: - 请求通知权限
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("[App] 通知权限已授予")
            } else {
                print("[App] 通知权限被拒绝")
            }
        }
        
        // 注册来电通知类别
        let answerAction = UNNotificationAction(
            identifier: "ANSWER_CALL",
            title: "接听",
            options: [.foreground]
        )
        let rejectAction = UNNotificationAction(
            identifier: "REJECT_CALL",
            title: "拒接",
            options: [.destructive]
        )
        
        let callCategory = UNNotificationCategory(
            identifier: "INCOMING_CALL",
            actions: [answerAction, rejectAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([callCategory])
        UNUserNotificationCenter.current().delegate = appDelegate
    }
}

// MARK: - 应用代理
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 初始化服务（v2：模块连接管理器优先，通过 ECM 网卡探测模块）
        _ = ModuleConnectionManager.shared
        _ = USBCommunicationManager.shared
        _ = ATCommandManager.shared
        _ = CallManager.shared
        _ = SMSManager.shared
        _ = ContactManager.shared
        _ = NetworkManager.shared
        _ = GPSManager.shared
        _ = eSIMManager.shared
        
        // 开始网络监控
        NetworkManager.shared.startMonitoring()
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // 停止网络监控
        NetworkManager.shared.stopMonitoring()
    }
    
    // MARK: - 通知处理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case "ANSWER_CALL":
            CallManager.shared.answer()
        case "REJECT_CALL":
            CallManager.shared.reject()
        default:
            break
        }
        completionHandler()
    }
    
    // MARK: - 外部附件连接
    func application(
        _ application: UIApplication,
        shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier
    ) -> Bool {
        return true
    }
}
