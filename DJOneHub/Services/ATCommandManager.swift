import Foundation
import Combine

// MARK: - AT 指令管理器
/// 负责发送 AT 指令并解析响应，管理模块状态
final class ATCommandManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = ATCommandManager()
    
    // MARK: - 发布属性
    @Published private(set) var moduleStatus = ModuleStatus.disconnected
    @Published private(set) var isCommandExecuting = false
    @Published private(set) var lastCommand: String?
    @Published private(set) var lastResponse: String?
    @Published private(set) var commandHistory: [CommandRecord] = []
    
    // MARK: - 回调
    var onIncomingCall: ((String) -> Void)?
    var onNewSMS: ((String, String) -> Void)?
    var onSignalUpdate: ((Int) -> Void)?
    var onStatusUpdate: ((ModuleStatus) -> Void)?
    
    // MARK: - 私有属性
    private let moduleConnection = ModuleConnectionManager.shared
    private let usbManager = USBCommunicationManager.shared
    private let networkManager = NetworkCommunicationManager.shared
    private var responseBuffer = ""
    private let responseLock = NSLock()
    private var commandQueue = DispatchQueue(label: "com.djonehub.atcommand", qos: .userInitiated)
    private var statusUpdateTimer: Timer?
    private var isListeningForURC = false

    /// 当前使用的通信方式：模块连接管理器（ECM TCP/HTTP）优先，其次旧网络桥接，最后 MFi USB
    private var useNetwork: Bool {
        return moduleConnection.isConnected || networkManager.isConnected
    }
    
    // MARK: - 命令记录
    struct CommandRecord: Identifiable {
        let id = UUID()
        let command: String
        let response: String
        let timestamp: Date
        let success: Bool
    }
    
    // MARK: - 初始化
    private init() {
        setupUSBCallbacks()
        startStatusMonitoring()
    }
    
    // MARK: - USB/网络 回调设置
    private func setupUSBCallbacks() {
        // 模块连接管理器（v2 主通道：ECM 网卡 → TCP/HTTP AT 桥接）
        moduleConnection.onDataReceived = { [weak self] data in
            self?.handleReceivedData(data)
        }
        moduleConnection.onConnectionStateChanged = { [weak self] connected in
            if connected {
                self?.initializeModule()
            } else {
                self?.moduleStatus = .disconnected
                self?.stopStatusMonitoring()
            }
        }

        // USB 回调（MFi 遗留回退）
        usbManager.onDataReceived = { [weak self] data in
            self?.handleReceivedData(data)
        }
        
        usbManager.onConnectionStateChanged = { [weak self] connected in
            if connected {
                self?.initializeModule()
            } else {
                self?.moduleStatus = .disconnected
                self?.stopStatusMonitoring()
            }
        }
        
        // 网络回调
        networkManager.onDataReceived = { [weak self] data in
            self?.handleReceivedData(data)
        }
        
        networkManager.onConnectionStateChanged = { [weak self] connected in
            if connected {
                self?.initializeModule()
            } else {
                self?.moduleStatus = .disconnected
                self?.stopStatusMonitoring()
            }
        }
    }
    
    // MARK: - 处理接收到的数据
    private func handleReceivedData(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        
        responseLock.lock()
        responseBuffer += text
        responseLock.unlock()
        
        // 检查 URC（Unsolicited Result Code）- 主动上报
        processURC(text)
    }
    
    // MARK: - 处理主动上报
    private func processURC(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 来电通知
            if trimmed == "RING" {
                // 尝试获取来电号码（需要 +CLIP 启用）
                if let number = ATCommandParser.parseIncomingCall(text) {
                    onIncomingCall?(number)
                } else {
                    onIncomingCall?("未知号码")
                }
            }
            
            // 新短信通知
            if trimmed.hasPrefix("+CMT:") || trimmed.hasPrefix("+CMTI:") {
                if let sms = ATCommandParser.parseNewSMS(text) {
                    onNewSMS?(sms.phoneNumber, sms.content)
                }
            }
            
            // 信号强度变化
            if trimmed.hasPrefix("+CSQ:") {
                let signal = ATCommandParser.parseSignalStrength(text)
                onSignalUpdate?(signal.rssi)
            }
        }
    }
    
    // MARK: - 发送 AT 指令并等待响应
    func sendCommand(_ command: String, timeout: TimeInterval = 5.0) async throws -> String {
        // 如果网络已连接，优先通过网络发送
        if useNetwork {
            return try await sendCommandViaNetwork(command, timeout: timeout)
        }
        
        // 否则通过 USB 发送
        guard usbManager.isConnected else {
            throw ATError.deviceNotConnected
        }
        
        isCommandExecuting = true
        lastCommand = command
        
        // 清空响应缓冲区
        responseLock.lock()
        responseBuffer = ""
        responseLock.unlock()
        
        // 发送命令
        let success = usbManager.send(command: command)
        guard success else {
            isCommandExecuting = false
            throw ATError.sendFailed
        }
        
        // 等待响应
        let response = try await waitForResponse(timeout: timeout)
        
        isCommandExecuting = false
        lastResponse = response
        
        // 记录历史
        let isSuccess = !response.contains("ERROR")
        commandHistory.insert(
            CommandRecord(command: command, response: response, timestamp: Date(), success: isSuccess),
            at: 0
        )
        if commandHistory.count > 100 {
            commandHistory.removeLast()
        }
        
        if response.contains("ERROR") {
            throw ATError.commandError(response)
        }
        
        return response
    }
    
    // MARK: - 通过网络发送 AT 指令（优先 v2 模块连接管理器）
    private func sendCommandViaNetwork(_ command: String, timeout: TimeInterval) async throws -> String {
        isCommandExecuting = true
        lastCommand = command

        do {
            let response: String
            if moduleConnection.isConnected {
                switch moduleConnection.transport {
                case .tcp:
                    // TCP 直连：发送命令并按行读取响应
                    moduleConnection.tcpSend(Data((command + "\r\n").utf8))
                    var text = ""
                    let deadline = Date().addingTimeInterval(timeout)
                    while Date() < deadline {
                        if let chunk = await moduleConnection.tcpReadLine(timeout: 1.0) {
                            text += chunk
                            if text.contains("OK\r\n") || text.contains("OK\n") || text.contains("ERROR") {
                                break
                            }
                        }
                    }
                    response = text.trimmingCharacters(in: .whitespacesAndNewlines)
                default:
                    // HTTP 桥接（DjiModemSuite /api/at）
                    response = try await moduleConnection.sendATViaHTTP(command, timeout: timeout)
                }
            } else {
                response = try await networkManager.sendATCommand(command, timeout: timeout)
            }

            isCommandExecuting = false
            lastResponse = response

            let isSuccess = !response.contains("ERROR")
            commandHistory.insert(
                CommandRecord(command: command, response: response, timestamp: Date(), success: isSuccess),
                at: 0
            )
            if commandHistory.count > 100 {
                commandHistory.removeLast()
            }

            if response.contains("ERROR") {
                throw ATError.commandError(response)
            }

            return response
        } catch {
            isCommandExecuting = false
            throw error
        }
    }

    // MARK: - 旧 HTTP 桥接路径（保留）
    private func sendCommandViaLegacyNetwork(_ command: String, timeout: TimeInterval) async throws -> String {
        isCommandExecuting = true
        lastCommand = command

        do {
            let response = try await networkManager.sendATCommand(command, timeout: timeout)
            
            isCommandExecuting = false
            lastResponse = response
            
            // 记录历史
            let isSuccess = !response.contains("ERROR")
            commandHistory.insert(
                CommandRecord(command: command, response: response, timestamp: Date(), success: isSuccess),
                at: 0
            )
            if commandHistory.count > 100 {
                commandHistory.removeLast()
            }
            
            if response.contains("ERROR") {
                throw ATError.commandError(response)
            }
            
            return response
        } catch {
            isCommandExecuting = false
            throw error
        }
    }
    
    // MARK: - 等待响应
    private func waitForResponse(timeout: TimeInterval) async throws -> String {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            responseLock.lock()
            let buffer = responseBuffer
            responseLock.unlock()
            
            // 检查是否收到完整响应（以 OK 或 ERROR 结尾）
            if buffer.hasSuffix("OK\r\n") || 
               buffer.hasSuffix("OK\n") ||
               buffer.contains("ERROR") {
                return buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // 短暂等待
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // 超时，返回已收到的内容
        responseLock.lock()
        let buffer = responseBuffer
        responseLock.unlock()
        
        if buffer.isEmpty {
            throw ATError.timeout
        }
        return buffer.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - 模块初始化
    private func initializeModule() {
        Task {
            do {
                // 基础初始化命令序列
                _ = try await sendCommand("AT")
                _ = try await sendCommand("ATE0") // 关闭回显
                _ = try await sendCommand("AT+CMEE=2") // 详细错误
                _ = try await sendCommand("AT+CLIP=1") // 启用来电显示
                _ = try await sendCommand("AT+CNMI=2,1,0,0,0") // 新短信通知
                _ = try await sendCommand("AT+CMGF=1") // 短信文本模式
                
                // 读取模块信息
                await refreshModuleStatus()
                
                startStatusMonitoring()
            } catch {
                print("[AT] 模块初始化失败: \(error)")
            }
        }
    }
    
    // MARK: - 刷新模块状态
    func refreshModuleStatus() async {
        do {
            var status = ModuleStatus.disconnected
            status.isConnected = moduleConnection.isConnected || networkManager.isConnected || usbManager.isConnected
            status.deviceName = moduleConnection.isConnected
                ? "DJI 4G Module (\(moduleConnection.transport.rawValue) \(moduleConnection.gatewayIP ?? ""))"
                : (networkManager.isConnected ? (networkManager.moduleIP ?? "DJI 4G Module")
                   : (usbManager.connectedAccessory?.name ?? "DJI 4G Module"))
            
            // 读取 IMEI
            let imeiResponse = try await sendCommand("AT+CGSN")
            status.imei = ATCommandParser.parseIMEI(imeiResponse)
            
            // 读取 IMSI
            let imsiResponse = try await sendCommand("AT+CIMI")
            status.imsi = ATCommandParser.parseIMSI(imsiResponse)
            
            // 读取 SIM 状态
            let simResponse = try await sendCommand("AT+CPIN?")
            status.simStatus = ATCommandParser.parseSIMStatus(simResponse)
            
            // 读取信号强度
            let csqResponse = try await sendCommand("AT+CSQ")
            let signal = ATCommandParser.parseSignalStrength(csqResponse)
            status.signalStrength = signal.rssi
            
            // 读取运营商信息
            let copsResponse = try await sendCommand("AT+COPS?")
            let operatorInfo = ATCommandParser.parseOperatorInfo(copsResponse)
            status.operatorName = operatorInfo.operatorName
            if let act = operatorInfo.accessTechnology {
                status.networkType = ATCommandParser.networkType(fromACT: act)
            }
            
            // 读取注册状态
            let cregResponse = try await sendCommand("AT+CREG?")
            let regInfo = ATCommandParser.parseRegistrationStatus(cregResponse)
            status.registrationStatus = ModuleStatus.RegistrationStatus(rawValue: "\(regInfo.stat)") ?? .unknown
            
            // 尝试读取 ICCID
            if let iccidResponse = try? await sendCommand("AT+ICCID") {
                status.iccid = ATCommandParser.parseICCID(iccidResponse)
            }
            
            await MainActor.run {
                self.moduleStatus = status
                self.onStatusUpdate?(status)
            }
        } catch {
            print("[AT] 刷新状态失败: \(error)")
        }
    }
    
    // MARK: - 状态监控
    private func startStatusMonitoring() {
        stopStatusMonitoring()
        
        DispatchQueue.main.async {
            self.statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                Task {
                    await self?.refreshModuleStatus()
                }
            }
        }
    }
    
    private func stopStatusMonitoring() {
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
    }
    
    // MARK: - 常用 AT 指令便捷方法
    
    /// 拨号
    func dial(number: String) async throws {
        _ = try await sendCommand("ATD\(number);")
    }
    
    /// 接听
    func answer() async throws {
        _ = try await sendCommand("ATA")
    }
    
    /// 挂断
    func hangup() async throws {
        _ = try await sendCommand("ATH")
    }
    
    /// 发送 DTMF
    func sendDTMF(_ digit: String) async throws {
        _ = try await sendCommand("AT+VTS=\(digit)")
    }
    
    /// 发送短信
    func sendSMS(number: String, content: String) async throws {
        _ = try await sendCommand("AT+CMGF=1")
        _ = try await sendCommand("AT+CMGS=\"\(number)\"")
        // 发送短信内容，以 Ctrl+Z (0x1A) 结尾
        let payload = content + "\u{1A}"

        if moduleConnection.isConnected {
            switch moduleConnection.transport {
            case .tcp:
                moduleConnection.tcpSend(Data(payload.utf8))
            default:
                _ = try await moduleConnection.sendRawViaHTTP(payload, timeout: 30.0)
            }
        } else if networkManager.isConnected {
            _ = networkManager.send(command: payload)
        } else {
            guard usbManager.send(command: payload) else {
                throw ATError.sendFailed
            }
        }
        // 等待发送结果响应
        let _ = try await waitForResponse(timeout: 30.0)
    }
    
    /// 读取短信列表
    func readSMSList(status: String = "ALL") async throws -> [SMSMessage] {
        let response = try await sendCommand("AT+CMGL=\"\(status)\"")
        return ATCommandParser.parseSMSList(response)
    }
    
    /// 删除短信
    func deleteSMS(index: Int) async throws {
        _ = try await sendCommand("AT+CMGD=\(index)")
    }
    
    /// 设置 USB 配置（切换 iPhone/iPad 模式）
    func setUSBConfig(_ config: String) async throws {
        _ = try await sendCommand("AT+USBCFG=\(config)")
    }
    
    /// 读取 USB 配置
    func getUSBConfig() async throws -> String {
        let response = try await sendCommand("AT+USBCFG?")
        return response
    }
    
    /// 启用 GPS
    func enableGPS() async throws {
        _ = try await sendCommand("AT+QGPS=1")
    }
    
    /// 禁用 GPS
    func disableGPS() async throws {
        _ = try await sendCommand("AT+QGPSEND")
    }
    
    /// 读取 GPS 位置
    func getGPSPosition() async throws -> (lat: Double, lon: Double, alt: Double)? {
        let response = try await sendCommand("AT+QGPSLOC?")
        // 解析 +QGPSLOC: <UTC>,<latitude>,<longitude>,<hdop>,<altitude>,<fix>,<cog>,<spkm>,<spkn>,<date>,<nsat>
        let components = response.components(separatedBy: ",")
        guard components.count >= 5 else { return nil }
        
        let latStr = components[1].trimmingCharacters(in: .whitespaces)
        let lonStr = components[2].trimmingCharacters(in: .whitespaces)
        let altStr = components[4].trimmingCharacters(in: .whitespaces)
        
        guard let lat = Double(latStr),
              let lon = Double(lonStr),
              let alt = Double(altStr) else {
            return nil
        }
        
        return (lat / 1000000, lon / 1000000, alt)
    }
    
    // MARK: - 错误类型
    enum ATError: LocalizedError {
        case deviceNotConnected
        case sendFailed
        case timeout
        case commandError(String)
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .deviceNotConnected:
                return "设备未连接"
            case .sendFailed:
                return "指令发送失败"
            case .timeout:
                return "响应超时"
            case .commandError(let response):
                return "指令执行错误: \(response)"
            case .invalidResponse:
                return "无效的响应"
            }
        }
    }
}
