import Foundation

// MARK: - UserDefaults 键名定义
enum UserDefaultsKeys {
    // 模块设置
    static let autoConnect = "auto_connect"
    static let connectionMode = "connection_mode"  // iPhone / iPad / Full
    static let usbConfig = "usb_config"
    
    // 网络设置
    static let dataEnabled = "data_enabled"
    static let roamingEnabled = "roaming_enabled"
    static let apn = "apn_setting"
    static let networkMode = "network_mode"
    static let wifiPriority = "wifi_priority"
    
    // 短信设置
    static let smsAutoDelete = "sms_auto_delete"
    static let smsNotificationEnabled = "sms_notification_enabled"
    static let smsVerificationPreview = "sms_verification_preview"
    
    // 通话设置
    static let callNotificationEnabled = "call_notification_enabled"
    static let autoAnswer = "auto_answer"
    static let autoAnswerDelay = "auto_answer_delay"
    static let callRecordingEnabled = "call_recording_enabled"
    static let speakerDefault = "speaker_default"
    
    // 通讯录设置
    static let contactsSyncEnabled = "contacts_sync_enabled"
    
    // GPS 设置
    static let gpsEnabled = "gps_enabled"
    static let gpsUpdateInterval = "gps_update_interval"
    
    // 语音运行时
    static let voiceRuntimeConfirmed = "voice_runtime_confirmed"
    static let voiceRuntimeVersion = "voice_runtime_version"
    static let voiceRuntimeCached = "voice_runtime_cached"
    
    // 数据存储
    static let callRecords = "call_records"
    static let smsMessages = "sms_messages"
    static let knownContacts = "known_contacts"
    
    // 应用设置
    static let appTheme = "app_theme"
    static let appLanguage = "app_language"
    static let lastConnectedDevice = "last_connected_device"
    static let hasCompletedOnboarding = "has_completed_onboarding"
}

// MARK: - 连接模式枚举
enum ConnectionMode: String, CaseIterable, Identifiable {
    case full = "full"
    case iPhone = "iphone"
    case iPad = "ipad"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .full: return "完整模式"
        case .iPhone: return "iPhone 模式"
        case .iPad: return "iPad 模式"
        }
    }
    
    var description: String {
        switch self {
        case .full: return "启用 USB Audio、4G、AT 和短信全部接口"
        case .iPhone: return "关闭 USB Audio，保留 4G、AT 和短信"
        case .iPad: return "关闭 USB Audio，保留 4G、AT 和短信，优化大屏显示"
        }
    }
}

// MARK: - 应用主题
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}
