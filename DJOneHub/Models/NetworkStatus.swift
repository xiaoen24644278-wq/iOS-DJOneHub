import Foundation

// MARK: - 网络状态模型
struct NetworkStatus: Equatable {
    var isConnected: Bool
    var interfaceType: InterfaceType
    var ipAddress: String?
    var subnetMask: String?
    var gateway: String?
    var dnsServers: [String]
    var isDataEnabled: Bool
    var isRoaming: Bool
    var apn: String
    var signalStrength: Int
    var networkMode: NetworkMode
    
    enum InterfaceType: String, Equatable {
        case none = "none"
        case wifi = "Wi-Fi"
        case cellular = "蜂窝网络"
        case ethernet = "以太网"
        case usb = "USB 网络"
    }
    
    enum NetworkMode: String, Equatable {
        case auto = "自动"
        case gsmOnly = "仅 GSM"
        case wcdmaOnly = "仅 WCDMA"
        case lteOnly = "仅 LTE"
        case nrOnly = "仅 5G"
        case lteNr = "LTE/5G"
    }
    
    static let disconnected = NetworkStatus(
        isConnected: false,
        interfaceType: .none,
        ipAddress: nil,
        subnetMask: nil,
        gateway: nil,
        dnsServers: [],
        isDataEnabled: false,
        isRoaming: false,
        apn: "",
        signalStrength: 0,
        networkMode: .auto
    )
}

// MARK: - 流量统计
struct TrafficStats: Equatable {
    var totalBytesSent: UInt64
    var totalBytesReceived: UInt64
    var sessionBytesSent: UInt64
    var sessionBytesReceived: UInt64
    var sessionStartTime: Date?
    
    var totalSentString: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytesSent), countStyle: .binary)
    }
    
    var totalReceivedString: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytesReceived), countStyle: .binary)
    }
    
    var sessionSentString: String {
        ByteCountFormatter.string(fromByteCount: Int64(sessionBytesSent), countStyle: .binary)
    }
    
    var sessionReceivedString: String {
        ByteCountFormatter.string(fromByteCount: Int64(sessionBytesReceived), countStyle: .binary)
    }
    
    static let zero = TrafficStats(
        totalBytesSent: 0,
        totalBytesReceived: 0,
        sessionBytesSent: 0,
        sessionBytesReceived: 0,
        sessionStartTime: nil
    )
}

// MARK: - eSIM / eUICC 状态
struct eSIMStatus: Equatable {
    var eid: String
    var firmwareVersion: String
    var freeSpace: Int64
    var totalSpace: Int64
    var profiles: [eSIMProfile]
    
    struct eSIMProfile: Identifiable, Equatable {
        let id: String
        let iccid: String
        let name: String
        let providerName: String
        let state: ProfileState
        let isEnabled: Bool
        
        enum ProfileState: String, Equatable {
            case enabled = "Enabled"
            case disabled = "Disabled"
            case downloading = "Downloading"
            case installing = "Installing"
            case error = "Error"
        }
    }
    
    static let empty = eSIMStatus(
        eid: "-",
        firmwareVersion: "-",
        freeSpace: 0,
        totalSpace: 0,
        profiles: []
    )
}
