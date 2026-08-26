import Foundation
import Combine
import Network

// MARK: - 网络管理器
final class NetworkManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = NetworkManager()
    
    // MARK: - 发布属性
    @Published private(set) var networkStatus = NetworkStatus.disconnected
    @Published private(set) var trafficStats = TrafficStats.zero
    @Published private(set) var isMonitoring = false
    
    // MARK: - 私有属性
    private let atManager = ATCommandManager.shared
    private let userDefaults = UserDefaults.standard
    private var monitor: NWPathMonitor?
    private var trafficTimer: Timer?
    
    // MARK: - 初始化
    private init() {
        loadSettings()
    }
    
    // MARK: - 加载设置
    private func loadSettings() {
        networkStatus.isDataEnabled = userDefaults.bool(forKey: UserDefaultsKeys.dataEnabled)
        networkStatus.isRoaming = userDefaults.bool(forKey: UserDefaultsKeys.roamingEnabled)
        networkStatus.apn = userDefaults.string(forKey: UserDefaultsKeys.apn) ?? ""
    }
    
    // MARK: - 开始网络监控
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        
        let queue = DispatchQueue(label: "com.djonehub.networkmonitor")
        monitor?.start(queue: queue)
        
        isMonitoring = true
        startTrafficMonitoring()
    }
    
    // MARK: - 停止网络监控
    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
        stopTrafficMonitoring()
        isMonitoring = false
    }
    
    // MARK: - 处理网络路径更新
    private func handlePathUpdate(_ path: NWPath) {
        DispatchQueue.main.async {
            var status = self.networkStatus
            status.isConnected = path.status == .satisfied
            
            // 判断接口类型
            if path.usesInterfaceType(.wifi) {
                status.interfaceType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                status.interfaceType = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                status.interfaceType = .ethernet
            } else {
                status.interfaceType = .none
            }
            
            self.networkStatus = status
        }
    }
    
    // MARK: - 流量监控
    private func startTrafficMonitoring() {
        trafficStats.sessionStartTime = Date()
        
        DispatchQueue.main.async {
            self.trafficTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.updateTrafficStats()
            }
        }
    }
    
    private func stopTrafficMonitoring() {
        trafficTimer?.invalidate()
        trafficTimer = nil
    }
    
    private func updateTrafficStats() {
        // 这里应该从系统获取实际流量统计
        // iOS 上获取精确的网络流量统计比较受限，这里使用模拟数据
        // 实际实现可以参考 ifaddrs 等系统 API
    }
    
    // MARK: - 启用/禁用数据
    func setDataEnabled(_ enabled: Bool) {
        networkStatus.isDataEnabled = enabled
        userDefaults.set(enabled, forKey: UserDefaultsKeys.dataEnabled)
        
        Task {
            // 通过 AT 指令控制数据连接
            if enabled {
                _ = try? await atManager.sendCommand("AT+CGATT=1")
            } else {
                _ = try? await atManager.sendCommand("AT+CGATT=0")
            }
        }
    }
    
    // MARK: - 设置网络模式
    func setNetworkMode(_ mode: NetworkStatus.NetworkMode) {
        networkStatus.networkMode = mode
        
        Task {
            let atCommand: String
            switch mode {
            case .auto:
                atCommand = "AT+QNWPREFCFG=\"mode_pref\",AUTO"
            case .gsmOnly:
                atCommand = "AT+QNWPREFCFG=\"mode_pref\",GSM"
            case .wcdmaOnly:
                atCommand = "AT+QNWPREFCFG=\"mode_pref\",WCDMA"
            case .lteOnly:
                atCommand = "AT+QNWPREFCFG=\"mode_pref\",LTE"
            case .nrOnly:
                atCommand = "AT+QNWPREFCFG=\"mode_pref\",NR5G"
            case .lteNr:
                atCommand = "AT+QNWPREFCFG=\"mode_pref\",LTE:NR5G"
            }
            _ = try? await atManager.sendCommand(atCommand)
        }
    }
    
    // MARK: - 设置 APN
    func setAPN(_ apn: String) {
        networkStatus.apn = apn
        userDefaults.set(apn, forKey: UserDefaultsKeys.apn)
        
        Task {
            _ = try? await atManager.sendCommand("AT+CGDCONT=1,\"IP\",\"\(apn)\"")
        }
    }
    
    // MARK: - 启用/禁用漫游
    func setRoamingEnabled(_ enabled: Bool) {
        networkStatus.isRoaming = enabled
        userDefaults.set(enabled, forKey: UserDefaultsKeys.roamingEnabled)
        
        Task {
            if enabled {
                _ = try? await atManager.sendCommand("AT+QROAM=1")
            } else {
                _ = try? await atManager.sendCommand("AT+QROAM=0")
            }
        }
    }
    
    // MARK: - 网络诊断
    func runNetworkDiagnostics() async -> [String: String] {
        var results: [String: String] = [:]
        
        do {
            // 检查 PDP 上下文
            let cgdcont = try await atManager.sendCommand("AT+CGDCONT?")
            results["PDP上下文"] = cgdcont
            
            // 检查网络注册
            let creg = try await atManager.sendCommand("AT+CREG?")
            results["网络注册"] = creg
            
            // 检查信号
            let csq = try await atManager.sendCommand("AT+CSQ")
            results["信号强度"] = csq
            
            // 检查运营商
            let cops = try await atManager.sendCommand("AT+COPS?")
            results["运营商"] = cops
            
        } catch {
            results["错误"] = error.localizedDescription
        }
        
        return results
    }
}
