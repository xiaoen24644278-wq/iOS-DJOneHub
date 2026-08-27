import Foundation
import Combine
import Network

// MARK: - 网络通信管理器
/// 通过 USB ECM 网络与模块侧的 AT/HTTP 桥接服务通信
final class NetworkCommunicationManager: NSObject, ObservableObject {
    
    // MARK: - 单例
    static let shared = NetworkCommunicationManager()
    
    // MARK: - 发布属性
    @Published private(set) var isConnected = false
    @Published private(set) var moduleIP: String?
    @Published private(set) var modulePort: Int = 80
    @Published private(set) var connectionError: Error?
    @Published private(set) var isScanning = false
    @Published private(set) var discoveredModules: [DiscoveredModule] = []
    
    // MARK: - 私有属性
    private var urlSession: URLSession!
    private var webSocketTask: URLSessionWebSocketTask?
    private let userDefaults = UserDefaults.standard
    private var receiveBuffer = ""
    private let bufferLock = NSLock()
    
    /// 数据回调
    var onDataReceived: ((Data) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?
    
    // MARK: - 常见的模块 IP 地址和端口
    private let commonIPs = [
        "192.168.225.1",
        "192.168.42.129",
        "192.168.1.1",
        "192.168.0.1",
        "10.0.0.1"
    ]
    
    private let commonPorts = [80, 8080, 8000, 5000, 3000]
    
    // MARK: - 已发现的模块
    struct DiscoveredModule: Identifiable {
        let id = UUID()
        let ip: String
        let port: Int
        let name: String
    }
    
    // MARK: - 初始化
    private override init() {
        super.init()
        setupURLSession()
        loadSavedConfig()
    }
    
    // MARK: - 设置 URLSession
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }
    
    // MARK: - 加载保存的配置
    private func loadSavedConfig() {
        if let ip = userDefaults.string(forKey: UserDefaultsKeys.moduleIP) {
            moduleIP = ip
        }
        let port = userDefaults.integer(forKey: UserDefaultsKeys.modulePort)
        if port > 0 {
            modulePort = port
        }
    }
    
    // MARK: - 保存配置
    private func saveConfig(ip: String, port: Int) {
        userDefaults.set(ip, forKey: UserDefaultsKeys.moduleIP)
        userDefaults.set(port, forKey: UserDefaultsKeys.modulePort)
    }
    
    // MARK: - 扫描发现模块
    func scanForModules() async {
        await MainActor.run {
            isScanning = true
            discoveredModules.removeAll()
        }
        
        // 并行扫描所有常见的 IP:Port 组合
        await withTaskGroup(of: DiscoveredModule?.self) { group in
            for ip in commonIPs {
                for port in commonPorts {
                    group.addTask {
                        return await self.checkModule(ip: ip, port: port)
                    }
                }
            }
            
            for await result in group {
                if let module = result {
                    await MainActor.run {
                        discoveredModules.append(module)
                    }
                }
            }
        }
        
        await MainActor.run {
            isScanning = false
        }
    }
    
    // MARK: - 检查单个模块
    private func checkModule(ip: String, port: Int) async -> DiscoveredModule? {
        guard let url = URL(string: "http://\(ip):\(port)/api/status") else { return nil }
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            // 尝试解析响应，获取模块名称
            var name = "DJI Module"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let moduleName = json["name"] as? String {
                name = moduleName
            }
            
            return DiscoveredModule(ip: ip, port: port, name: name)
        } catch {
            return nil
        }
    }
    
    // MARK: - 连接到模块
    func connect(to ip: String, port: Int = 80) async -> Bool {
        await MainActor.run {
            moduleIP = ip
            modulePort = port
            connectionError = nil
        }
        
        // 测试连接
        let isReachable = await testConnection(ip: ip, port: port)
        
        if isReachable {
            saveConfig(ip: ip, port: port)
            await MainActor.run {
                isConnected = true
            }
            onConnectionStateChanged?(true)
            startWebSocket()
            return true
        } else {
            await MainActor.run {
                connectionError = NetworkError.connectionFailed
                isConnected = false
            }
            return false
        }
    }
    
    // MARK: - 测试连接
    private func testConnection(ip: String, port: Int) async -> Bool {
        guard let url = URL(string: "http://\(ip):\(port)/api/status") else { return false }
        
        do {
            let (_, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: - 断开连接
    func disconnect() {
        webSocketTask?.cancel()
        webSocketTask = nil
        
        isConnected = false
        onConnectionStateChanged?(false)
    }
    
    // MARK: - 启动 WebSocket（接收主动上报 URC）
    private func startWebSocket() {
        guard let ip = moduleIP else { return }
        guard let url = URL(string: "ws://\(ip):\(modulePort)/ws/events") else { return }
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveWebSocketMessage()
    }
    
    // MARK: - 接收 WebSocket 消息
    private func receiveWebSocketMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleWebSocketText(text)
                case .data(let data):
                    self.handleWebSocketData(data)
                @unknown default:
                    break
                }
                self.receiveWebSocketMessage()
                
            case .failure:
                // WebSocket 断开，尝试重连
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self.isConnected {
                        self.startWebSocket()
                    }
                }
            }
        }
    }
    
    // MARK: - 处理 WebSocket 文本消息
    private func handleWebSocketText(_ text: String) {
        // URC 主动上报，通过回调传递给 ATCommandManager
        if let data = text.data(using: .utf8) {
            onDataReceived?(data)
        }
    }
    
    // MARK: - 处理 WebSocket 数据消息
    private func handleWebSocketData(_ data: Data) {
        onDataReceived?(data)
    }
    
    // MARK: - 发送 AT 命令（通过 HTTP）
    func sendATCommand(_ command: String, timeout: TimeInterval = 5.0) async throws -> String {
        guard isConnected, let ip = moduleIP else {
            throw NetworkError.notConnected
        }
        
        guard let url = URL(string: "http://\(ip):\(modulePort)/api/at") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        let body: [String: Any] = [
            "command": command,
            "timeout": Int(timeout * 1000)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // 解析响应
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = json["response"] as? String {
            return result
        } else if let text = String(data: data, encoding: .utf8) {
            return text
        } else {
            throw NetworkError.invalidResponse
        }
    }
    
    // MARK: - 发送数据
    func send(data: Data) -> Bool {
        // 通过 HTTP 发送数据（异步）
        Task {
            if let command = String(data: data, encoding: .utf8) {
                _ = try? await sendATCommand(command)
            }
        }
        return true
    }
    
    func send(command: String) -> Bool {
        Task {
            _ = try? await sendATCommand(command)
        }
        return true
    }
    
    // MARK: - 读取可用数据
    func readAvailableData() -> Data? {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        guard !receiveBuffer.isEmpty else { return nil }
        let data = receiveBuffer.data(using: .utf8)
        receiveBuffer.removeAll()
        return data
    }
    
    // MARK: - 获取模块状态
    func getModuleStatus() async -> [String: Any]? {
        guard isConnected, let ip = moduleIP else { return nil }
        guard let url = URL(string: "http://\(ip):\(modulePort)/api/status") else { return nil }
        
        do {
            let (data, _) = try await urlSession.data(from: url)
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            return nil
        }
    }
}

// MARK: - URLSessionDelegate
extension NetworkCommunicationManager: URLSessionDelegate, URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[Network] WebSocket 已连接")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[Network] WebSocket 已断开")
    }
}

// MARK: - 错误类型
extension NetworkCommunicationManager {
    enum NetworkError: LocalizedError {
        case notConnected
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int)
        case connectionFailed
        case timeout
        
        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "未连接到模块"
            case .invalidURL:
                return "无效的 URL"
            case .invalidResponse:
                return "无效的响应"
            case .httpError(let statusCode):
                return "HTTP 错误: \(statusCode)"
            case .connectionFailed:
                return "连接失败"
            case .timeout:
                return "连接超时"
            }
        }
    }
}
