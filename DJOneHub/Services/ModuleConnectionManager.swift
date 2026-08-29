import Foundation
import Network
import Combine

// MARK: - 模块连接管理器（v2 核心）
/// 解决旧版“无法识别 4G 模块”的根本问题：
/// iOS 把大疆 4G 模块枚举为 USB ECM 以太网卡（非 MFi 设备），
/// ExternalAccessory 永远收不到该设备。
///
/// 正确路径（按图片思路）：
///   模块 ECM 网卡 → iOS 原生支持 → 可上网
///   模块 AT 控制口 → 通过 ECM 局域网 TCP/HTTP 桥接 → 本管理器
///
/// 工作方式：
/// 1. NWPathMonitor 监听网络接口，识别有线/ECM 接口（en*、bridge*、usb*）
/// 2. 对候选网关 IP（192.168.225.1 等）做 TCP 端口探测 + HTTP /api/status 探测
/// 3. 优先建立持久 TCP AT 通道；失败则退回 HTTP /api/at 轮询模式
/// 4. 网络路径变化时自动重连；ExternalAccessory 仅作遗留回退
final class ModuleConnectionManager: ObservableObject {

    static let shared = ModuleConnectionManager()

    // MARK: - 状态
    enum Transport: String {
        case none = "未连接"
        case tcp = "TCP 直连"
        case http = "HTTP 桥接"
        case accessory = "MFi 附件"
    }

    enum Phase: Equatable {
        case idle
        case detectingInterface
        case probingGateways
        case connecting(String)
        case connected(Transport)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var transport: Transport = .none
    @Published private(set) var gatewayIP: String?
    @Published private(set) var gatewayPort: Int = 0
    @Published private(set) var interfaceName: String?
    @Published private(set) var localIP: String?
    @Published private(set) var lastProbeLog: [String] = []
    @Published private(set) var isProbing = false

    /// URC 主动上报（WebSocket / TCP 通道收到的下行数据）
    var onDataReceived: ((Data) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?

    var isConnected: Bool {
        if case .connected = phase { return true }
        return false
    }

    // MARK: - 候选地址（大疆/移远常见 ECM 网关 + DjiModemSuite 桥接端口）
    private let candidateIPs = [
        "192.168.225.1",   // Quectel ECM 默认网关
        "192.168.42.129",  // Quectel RNDIS 常见
        "192.168.43.1",
        "192.168.1.1",
        "192.168.0.1",
        "10.0.0.1"
    ]
    private let candidateTCPPorts: [Int] = [7575, 8080, 23, 5555]  // AT over TCP 常见端口
    private let candidateHTTPPorts: [Int] = [80, 8080, 7575]

    // MARK: - 私有
    private var pathMonitor: NWPathMonitor?
    private var urlSession: URLSession!
    private var tcpConnection: NWConnection?
    private let queue = DispatchQueue(label: "com.djonehub.module-connection")
    private var reconnectWorkItem: DispatchWorkItem?
    private let defaults = UserDefaults.standard

    private struct K {
        static let ip = "djonehub.gateway.ip"
        static let port = "djonehub.gateway.port"
        static let transport = "djonehub.gateway.transport"
    }

    // MARK: - 初始化
    private init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 3
        cfg.timeoutIntervalForResource = 5
        urlSession = URLSession(configuration: cfg)
        startMonitoringPath()
    }

    // MARK: - 接口监测（识别 ECM 网卡）
    func startMonitoringPath() {
        pathMonitor?.cancel()
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let isECM = Self.looksLikeECM(path)
            let ifName = path.availableInterfaces.first?.name
            DispatchQueue.main.async {
                self.interfaceName = ifName
                self.localIP = Self.firstIPv4(from: path)
            }
            if path.status == .satisfied {
                if isECM && !self.isConnected {
                    // ECM 网卡出现：立即探测模块
                    Task { await self.autoConnect(reason: "ECM 接口 \(ifName ?? "?") 出现") }
                } else if !isECM && self.isConnected && Self.looksLikeECMDropped(self.gatewayIP) {
                    // 走向了别的网络（如 Wi-Fi），不主动断开 HTTP 模式，
                    // 但 ECM 直连可能失效，安排一次复检
                    self.scheduleRecheck()
                }
            } else {
                DispatchQueue.main.async {
                    if self.isConnected { self.teardown(transportDown: true) }
                }
            }
        }
        monitor.start(queue: queue)
    }

    /// ECM 特征：USB 有线网卡接口；排除 Wi-Fi / 蜂窝 / 回环
    static func looksLikeECM(_ path: NWPath) -> Bool {
        guard path.status == .satisfied else { return false }
        // 明确排除非 USB 路径
        if path.usesInterfaceType(.wifi)
            || path.usesInterfaceType(.cellular)
            || path.usesInterfaceType(.loopback) {
            return false
        }
        // iOS 上 USB ECM 网卡通常报告为 wiredEthernet
        if path.usesInterfaceType(.wiredEthernet) { return true }
        // 部分系统版本把 USB 网卡报为 other，按接口名兜底识别
        if let ifc = path.availableInterfaces.first {
            return ifc.name.hasPrefix("usb") || ifc.name.hasPrefix("bridge")
        }
        return false
    }

    static func firstIPv4(from path: NWPath) -> String? {
        // NWPath.gateways 返回网关地址（[NWEndpoint]）；NWEndpoint 无独立 .ipv4 case，只匹配 hostPort
        for endpoint in path.gateways {
            switch endpoint {
            case .hostPort(let host, _):
                if case .ipv4(let ip) = host { return "\(ip)" }
                if case .ipv6(let ip) = host { return "\(ip)" }
            default:
                break
            }
        }
        return nil
    }

    private static func looksLikeECMDropped(_ ip: String?) -> Bool { ip != nil }

    // MARK: - 自动连接（启动 / ECM 插入时调用）
    @discardableResult
    func autoConnect(reason: String = "启动") async -> Bool {
        await MainActor.run {
            _ = reason
            isProbing = true
            lastProbeLog.removeAll()
            phase = .probingGateways
        }
        log("开始探测模块网关（\(reason)）")

        // 1. 优先尝试上次成功的地址
        if let savedIP = defaults.string(forKey: K.ip) {
            let savedPort = defaults.integer(forKey: K.port)
            if savedPort > 0, await probeAndConnect(ip: savedIP, port: savedPort) {
                await MainActor.run { isProbing = false }
                return true
            }
        }

        // 2. 全量扫描候选 IP × 端口
        for ip in candidateIPs {
            for port in candidateTCPPorts {
                if await probeTCP(ip: ip, port: port) {
                    if await establishTCP(ip: ip, port: port) {
                        await finishConnect(ip: ip, port: port, transport: .tcp)
                        await MainActor.run { isProbing = false }
                        return true
                    }
                }
            }
        }
        for ip in candidateIPs {
            for port in candidateHTTPPorts {
                if await probeHTTP(ip: ip, port: port) {
                    await startWebSocketEvents(ip: ip, port: port)
                    await finishConnect(ip: ip, port: port, transport: .http)
                    await MainActor.run { isProbing = false }
                    return true
                }
            }
        }

        await MainActor.run {
            isProbing = false
            phase = .failed("未发现模块。请确认：① 模块已通过 USB 连接且 Lightning/USB-C 口支持数据传输；② 设置 → 个人热点/网络中 ECM 网卡已启用；③ 模块侧已刷入 DjiModemSuite 固件（提供 TCP/HTTP AT 桥接）。")
            onConnectionStateChanged?(false)
        }
        return false
    }

    private func finishConnect(ip: String, port: Int, transport: Transport) async {
        defaults.set(ip, forKey: K.ip)
        defaults.set(port, forKey: K.port)
        await MainActor.run {
            gatewayIP = ip
            gatewayPort = port
            self.transport = transport
            phase = .connected(transport)
            onConnectionStateChanged?(true)
        }
        log("已连接 \(transport.rawValue) \(ip):\(String(port))")
    }

    // MARK: - 探测
    private func probeAndConnect(ip: String, port: Int) async -> Bool {
        let saved = defaults.string(forKey: K.transport) ?? "tcp"
        if saved == "http" {
            if await probeHTTP(ip: ip, port: port) {
                await startWebSocketEvents(ip: ip, port: port)
                await finishConnect(ip: ip, port: port, transport: .http)
                return true
            }
        } else {
            if await probeTCP(ip: ip, port: port), await establishTCP(ip: ip, port: port) {
                await finishConnect(ip: ip, port: port, transport: .tcp)
                return true
            }
            if await probeHTTP(ip: ip, port: port) {
                await startWebSocketEvents(ip: ip, port: port)
                await finishConnect(ip: ip, port: port, transport: .http)
                return true
            }
        }
        return false
    }

    private func probeTCP(ip: String, port: Int) async -> Bool {
        return await withCheckedContinuation { cont in
            let conn = NWConnection(
                host: NWEndpoint.Host(ip),
                port: NWEndpoint.Port(rawValue: UInt16(port))!,
                using: .tcp
            )
            var resumed = false
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !resumed { resumed = true; cont.resume(returning: true) }
                    conn.cancel()
                case .failed, .cancelled:
                    if !resumed { resumed = true; cont.resume(returning: false) }
                default:
                    break
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 1.5) {
                if !resumed { resumed = true; conn.cancel(); cont.resume(returning: false) }
            }
        }
    }

    private func probeHTTP(ip: String, port: Int) async -> Bool {
        guard let url = URL(string: "http://\(ip):\(port)/api/status") else { return false }
        do {
            let (_, resp) = try await urlSession.data(from: url)
            log("HTTP 探测 \(ip):\(port) → \((resp as? HTTPURLResponse)?.statusCode ?? 0)")
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - TCP 持久 AT 通道
    private func establishTCP(ip: String, port: Int) async -> Bool {
        tcpConnection?.cancel()
        let conn = NWConnection(
            host: NWEndpoint.Host(ip),
            port: NWEndpoint.Port(rawValue: UInt16(port))!,
            using: .tcp
        )
        tcpConnection = conn
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            var resumed = false
            conn.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    if !resumed { resumed = true; cont.resume(returning: true) }
                    self?.receiveLoop()
                case .failed, .cancelled:
                    if !resumed { resumed = true; cont.resume(returning: false) }
                    DispatchQueue.main.async { self?.handleTCPDown() }
                default:
                    break
                }
            }
            conn.start(queue: queue)
        }
    }

    private func receiveLoop() {
        tcpConnection?.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.onDataReceived?(data)
            }
            if error == nil && !isComplete {
                self?.receiveLoop()
            } else if error != nil {
                DispatchQueue.main.async { self?.handleTCPDown() }
            }
        }
    }

    private func handleTCPDown() {
        guard transport == .tcp, isConnected else { return }
        teardown(transportDown: true)
        scheduleRecheck()
    }

    /// TCP 通道读一行响应（供 ATCommandManager 同步等待用）
    func tcpReadLine(timeout: TimeInterval) async -> String? {
        guard let conn = tcpConnection else { return nil }
        return await withCheckedContinuation { cont in
            var resumed = false
            conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, error in
                if resumed { return }
                resumed = true
                if let data = data, let text = String(data: data, encoding: .utf8) {
                    cont.resume(returning: text)
                } else {
                    cont.resume(returning: nil)
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) {
                if !resumed { resumed = true; cont.resume(returning: nil) }
            }
        }
    }

    func tcpSend(_ data: Data) {
        tcpConnection?.send(content: data, completion: .contentProcessed { _ in })
    }

    // MARK: - HTTP 桥接：发送 AT
    func sendATViaHTTP(_ command: String, timeout: TimeInterval) async throws -> String {
        guard let ip = gatewayIP else { throw Error.notConnected }
        guard let url = URL(string: "http://\(ip):\(gatewayPort)/api/at") else { throw Error.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = max(timeout, 3)
        // DjiModemSuite 格式：{"command": "AT", "timeoutMs": 5000}
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "command": command,
            "timeoutMs": Int(timeout * 1000)
        ])
        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw Error.invalidResponse
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let ok = json["Ok"] as? Bool, ok {
                return (json["Data"] as? String) ?? ""
            }
            if let err = json["Error"] as? String, !err.isEmpty {
                throw Error.apiError(err)
            }
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// HTTP 模式下发送原始数据（如短信正文 + Ctrl+Z）
    func sendRawViaHTTP(_ raw: String, timeout: TimeInterval) async throws -> String {
        try await sendATViaHTTP(raw, timeout: timeout)
    }

    // MARK: - WebSocket 事件流（URC 上报）
    private func startWebSocketEvents(ip: String, port: Int) {
        guard let url = URL(string: "ws://\(ip):\(port)/ws/events") else { return }
        let task = urlSession.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        receiveWS()
    }

    private var webSocketTask: URLSessionWebSocketTask?

    private func receiveWS() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let msg):
                switch msg {
                case .string(let text):
                    self.onDataReceived?(Data(text.utf8))
                case .data(let data):
                    self.onDataReceived?(data)
                @unknown default:
                    break
                }
                self.receiveWS()
            case .failure:
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self.isConnected, let ip = self.gatewayIP {
                        self.startWebSocketEvents(ip: ip, port: self.gatewayPort)
                    }
                }
            }
        }
    }

    // MARK: - 断开 / 重连
    func disconnect() {
        teardown(transportDown: false)
    }

    private func teardown(transportDown: Bool) {
        tcpConnection?.cancel()
        tcpConnection = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        transport = .none
        phase = .idle
        onConnectionStateChanged?(false)
    }

    private func scheduleRecheck() {
        reconnectWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isConnected else { return }
            Task { await self.autoConnect(reason: "自动重连") }
        }
        reconnectWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }

    /// 手动刷新（设置页“重新检测”按钮）
    func rediscover() async {
        defaults.removeObject(forKey: K.ip)
        defaults.removeObject(forKey: K.port)
        teardown(transportDown: false)
        await autoConnect(reason: "手动重新检测")
    }

    // MARK: - 日志
    private func log(_ line: String) {
        DispatchQueue.main.async {
            self.lastProbeLog.append(line)
            if self.lastProbeLog.count > 200 {
                self.lastProbeLog.removeFirst(self.lastProbeLog.count - 200)
            }
        }
    }

    enum Error: LocalizedError {
        case notConnected, invalidURL, invalidResponse, apiError(String)
        var errorDescription: String? {
            switch self {
            case .notConnected: return "未连接到模块"
            case .invalidURL: return "无效的模块地址"
            case .invalidResponse: return "模块响应无效"
            case .apiError(let m): return "模块返回错误：\(m)"
            }
        }
    }
}
