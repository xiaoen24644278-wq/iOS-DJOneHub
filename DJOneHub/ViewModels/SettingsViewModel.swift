import Foundation
import Combine

// MARK: - 设置视图模型
final class SettingsViewModel: ObservableObject {
    
    // MARK: - 发布属性
    @Published var moduleStatus = ModuleStatus.disconnected
    @Published var networkStatus = NetworkStatus.disconnected
    @Published var gpsStatus = GPSStatus.disabled
    @Published var eSIMStatus: eSIMStatus = .empty
    @Published var trafficStats = TrafficStats.zero
    
    // 设置项
    @Published var autoConnect = true
    @Published var connectionMode: ConnectionMode = .full
    @Published var dataEnabled = true
    @Published var roamingEnabled = false
    @Published var apn = ""
    @Published var networkMode: NetworkStatus.NetworkMode = .auto
    @Published var wifiPriority = true
    
    @Published var smsAutoDelete = false
    @Published var smsNotificationEnabled = true
    @Published var smsVerificationPreview = true
    
    @Published var callNotificationEnabled = true
    @Published var autoAnswer = false
    @Published var autoAnswerDelay = 5.0
    @Published var callRecordingEnabled = false
    @Published var speakerDefault = false
    
    @Published var contactsSyncEnabled = true
    @Published var gpsEnabled = false
    @Published var appTheme: AppTheme = .system
    
    // AT 控制台
    @Published var atCommandInput = ""
    @Published var atCommandHistory: [ATCommandManager.CommandRecord] = []
    @Published var atResponse = ""
    @Published var isAtExecuting = false
    
    // MARK: - 服务引用
    private let atManager = ATCommandManager.shared
    private let networkManager = NetworkManager.shared
    private let gpsManager = GPSManager.shared
    let eSIMManager: eSIMManager = .shared
    private let userDefaults = UserDefaults.standard
    
    // MARK: - 取消包
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    init() {
        setupBindings()
        loadSettings()
    }
    
    // MARK: - 绑定
    private func setupBindings() {
        atManager.$moduleStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$moduleStatus)
        
        atManager.$commandHistory
            .receive(on: DispatchQueue.main)
            .assign(to: &$atCommandHistory)
        
        atManager.$isCommandExecuting
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAtExecuting)
        
        networkManager.$networkStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$networkStatus)
        
        networkManager.$trafficStats
            .receive(on: DispatchQueue.main)
            .assign(to: &$trafficStats)
        
        gpsManager.$gpsStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$gpsStatus)
        
        eSIMManager.$eSIMStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$eSIMStatus)
    }
    
    // MARK: - 加载设置
    private func loadSettings() {
        autoConnect = userDefaults.bool(forKey: UserDefaultsKeys.autoConnect)
        if let modeRaw = userDefaults.string(forKey: UserDefaultsKeys.connectionMode),
           let mode = ConnectionMode(rawValue: modeRaw) {
            connectionMode = mode
        }
        dataEnabled = userDefaults.bool(forKey: UserDefaultsKeys.dataEnabled)
        roamingEnabled = userDefaults.bool(forKey: UserDefaultsKeys.roamingEnabled)
        apn = userDefaults.string(forKey: UserDefaultsKeys.apn) ?? ""
        wifiPriority = userDefaults.bool(forKey: UserDefaultsKeys.wifiPriority)
        smsAutoDelete = userDefaults.bool(forKey: UserDefaultsKeys.smsAutoDelete)
        smsNotificationEnabled = userDefaults.bool(forKey: UserDefaultsKeys.smsNotificationEnabled)
        smsVerificationPreview = userDefaults.bool(forKey: UserDefaultsKeys.smsVerificationPreview)
        callNotificationEnabled = userDefaults.bool(forKey: UserDefaultsKeys.callNotificationEnabled)
        autoAnswer = userDefaults.bool(forKey: UserDefaultsKeys.autoAnswer)
        autoAnswerDelay = userDefaults.double(forKey: UserDefaultsKeys.autoAnswerDelay)
        callRecordingEnabled = userDefaults.bool(forKey: UserDefaultsKeys.callRecordingEnabled)
        speakerDefault = userDefaults.bool(forKey: UserDefaultsKeys.speakerDefault)
        contactsSyncEnabled = userDefaults.bool(forKey: UserDefaultsKeys.contactsSyncEnabled)
        gpsEnabled = userDefaults.bool(forKey: UserDefaultsKeys.gpsEnabled)
        if let themeRaw = userDefaults.string(forKey: UserDefaultsKeys.appTheme),
           let theme = AppTheme(rawValue: themeRaw) {
            appTheme = theme
        }
    }
    
    // MARK: - 保存设置
    func saveSettings() {
        userDefaults.set(autoConnect, forKey: UserDefaultsKeys.autoConnect)
        userDefaults.set(connectionMode.rawValue, forKey: UserDefaultsKeys.connectionMode)
        userDefaults.set(dataEnabled, forKey: UserDefaultsKeys.dataEnabled)
        userDefaults.set(roamingEnabled, forKey: UserDefaultsKeys.roamingEnabled)
        userDefaults.set(apn, forKey: UserDefaultsKeys.apn)
        userDefaults.set(wifiPriority, forKey: UserDefaultsKeys.wifiPriority)
        userDefaults.set(smsAutoDelete, forKey: UserDefaultsKeys.smsAutoDelete)
        userDefaults.set(smsNotificationEnabled, forKey: UserDefaultsKeys.smsNotificationEnabled)
        userDefaults.set(smsVerificationPreview, forKey: UserDefaultsKeys.smsVerificationPreview)
        userDefaults.set(callNotificationEnabled, forKey: UserDefaultsKeys.callNotificationEnabled)
        userDefaults.set(autoAnswer, forKey: UserDefaultsKeys.autoAnswer)
        userDefaults.set(autoAnswerDelay, forKey: UserDefaultsKeys.autoAnswerDelay)
        userDefaults.set(callRecordingEnabled, forKey: UserDefaultsKeys.callRecordingEnabled)
        userDefaults.set(speakerDefault, forKey: UserDefaultsKeys.speakerDefault)
        userDefaults.set(contactsSyncEnabled, forKey: UserDefaultsKeys.contactsSyncEnabled)
        userDefaults.set(gpsEnabled, forKey: UserDefaultsKeys.gpsEnabled)
        userDefaults.set(appTheme.rawValue, forKey: UserDefaultsKeys.appTheme)
    }
    
    // MARK: - 模块操作
    func refreshModuleStatus() async {
        await atManager.refreshModuleStatus()
    }
    
    // MARK: - 网络操作
    func setDataEnabled(_ enabled: Bool) {
        dataEnabled = enabled
        networkManager.setDataEnabled(enabled)
    }
    
    func setNetworkMode(_ mode: NetworkStatus.NetworkMode) {
        networkMode = mode
        networkManager.setNetworkMode(mode)
    }
    
    func setAPN(_ newAPN: String) {
        apn = newAPN
        networkManager.setAPN(newAPN)
    }
    
    func runNetworkDiagnostics() async -> [String: String] {
        await networkManager.runNetworkDiagnostics()
    }
    
    // MARK: - GPS 操作
    func toggleGPS() async {
        if gpsStatus.isEnabled {
            await gpsManager.disableGPS()
        } else {
            await gpsManager.enableGPS()
        }
    }
    
    // MARK: - eSIM 操作
    func refresheSIMInfo() async {
        await eSIMManager.refreshInfo()
    }
    
    func enableProfile(iccid: String) async {
        try? await eSIMManager.enableProfile(iccid: iccid)
    }
    
    func disableProfile(iccid: String) async {
        try? await eSIMManager.disableProfile(iccid: iccid)
    }
    
    func deleteProfile(iccid: String) async {
        try? await eSIMManager.deleteProfile(iccid: iccid)
    }
    
    // MARK: - AT 指令执行
    func executeATCommand() async {
        guard !atCommandInput.isEmpty else { return }
        
        let command = atCommandInput
        atCommandInput = ""
        
        do {
            let response = try await atManager.sendCommand(command)
            await MainActor.run {
                self.atResponse = response
            }
        } catch {
            await MainActor.run {
                self.atResponse = "错误: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 连接模式切换
    func setConnectionMode(_ mode: ConnectionMode) async {
        connectionMode = mode
        saveSettings()
        
        // 根据模式设置 USB 配置
        let usbConfig: String
        switch mode {
        case .full:
            usbConfig = "1,1,1,1,1,1,1" // 完整模式
        case .iPhone, .iPad:
            usbConfig = "1,1,1,1,1,0,1" // 关闭 USB Audio
        }
        
        do {
            try await atManager.setUSBConfig(usbConfig)
        } catch {
            print("[Settings] 设置 USB 配置失败: \(error)")
        }
    }
}
