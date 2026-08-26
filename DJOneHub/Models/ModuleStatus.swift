import Foundation

// MARK: - 模块状态模型
struct ModuleStatus: Equatable {
    var isConnected: Bool
    var deviceName: String
    var firmwareVersion: String
    var imei: String
    var imsi: String
    var iccid: String
    var simStatus: SIMStatus
    var signalStrength: Int  // 0-31, 99表示未知
    var networkType: NetworkType
    var operatorName: String
    var registrationStatus: RegistrationStatus
    var batteryLevel: Int?
    var isCharging: Bool
    
    enum SIMStatus: String, Equatable {
        case ready = "READY"
        case notInserted = "NOT INSERTED"
        case pinRequired = "PIN REQUIRED"
        case pukRequired = "PUK REQUIRED"
        case blocked = "BLOCKED"
        case unknown = "UNKNOWN"
    }
    
    enum NetworkType: String, Equatable {
        case noService = "NO SERVICE"
        case gsm = "GSM"
        case edge = "EDGE"
        case umts = "UMTS"
        case hsdpa = "HSDPA"
        case hsupa = "HSUPA"
        case lte = "LTE"
        case nr = "5G NR"
        case unknown = "UNKNOWN"
    }
    
    enum RegistrationStatus: String, Equatable {
        case notRegistered = "0"
        case registeredHome = "1"
        case searching = "2"
        case registrationDenied = "3"
        case unknown = "4"
        case registeredRoaming = "5"
    }
    
    var signalBars: Int {
        guard signalStrength >= 0 && signalStrength <= 31 else { return 0 }
        if signalStrength >= 25 { return 4 }
        if signalStrength >= 17 { return 3 }
        if signalStrength >= 9 { return 2 }
        if signalStrength >= 1 { return 1 }
        return 0
    }
    
    static let disconnected = ModuleStatus(
        isConnected: false,
        deviceName: "未连接",
        firmwareVersion: "-",
        imei: "-",
        imsi: "-",
        iccid: "-",
        simStatus: .unknown,
        signalStrength: 99,
        networkType: .unknown,
        operatorName: "-",
        registrationStatus: .unknown,
        batteryLevel: nil,
        isCharging: false
    )
}

// MARK: - GPS 状态
struct GPSStatus: Equatable {
    var isEnabled: Bool
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var speed: Double?
    var course: Double?
    var satellitesInView: Int
    var satellitesInUse: Int
    var fixQuality: FixQuality
    var timestamp: Date?
    
    enum FixQuality: Int, Equatable {
        case noFix = 0
        case gpsFix = 1
        case dgpsFix = 2
        case ppsFix = 3
        case rtkFixed = 4
        case rtkFloat = 5
        case estimated = 6
        case manual = 7
        case simulation = 8
    }
    
    static let disabled = GPSStatus(
        isEnabled: false,
        latitude: nil,
        longitude: nil,
        altitude: nil,
        speed: nil,
        course: nil,
        satellitesInView: 0,
        satellitesInUse: 0,
        fixQuality: .noFix,
        timestamp: nil
    )
}
