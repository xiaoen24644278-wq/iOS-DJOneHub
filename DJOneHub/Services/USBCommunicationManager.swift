import Foundation
import ExternalAccessory
import Combine

// MARK: - USB 通信管理器
/// 负责与大疆4G模块的 USB 串口通信
/// 使用 ExternalAccessory 框架与支持 MFi 协议的 USB 设备通信
final class USBCommunicationManager: NSObject, ObservableObject {
    
    // MARK: - 单例
    static let shared = USBCommunicationManager()
    
    // MARK: - 发布属性
    @Published private(set) var isConnected = false
    @Published private(set) var connectedAccessory: EAAccessory?
    @Published private(set) var connectionError: Error?
    
    // MARK: - 私有属性
    private var session: EASession?
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private let accessoryManager = EAAccessoryManager.shared()
    
    /// 支持的协议列表（大疆4G模块的 AT 指令通信协议）
    private let supportedProtocols = [
        "com.dji.cellular.at",
        "com.dji.cellular.usb",
        "com.qualcomm.at",
        "com.android.adb"
    ]
    
    /// 接收缓冲区
    private var receiveBuffer = Data()
    private let bufferLock = NSLock()
    
    /// 数据回调
    var onDataReceived: ((Data) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?
    
    // MARK: - 初始化
    private override init() {
        super.init()
        registerForAccessoryNotifications()
        checkConnectedAccessories()
    }
    
    // MARK: - 通知注册
    private func registerForAccessoryNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessoryConnected(_:)),
            name: .EAAccessoryDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessoryDisconnected(_:)),
            name: .EAAccessoryDidDisconnect,
            object: nil
        )
    }
    
    // MARK: - 检查已连接设备
    private func checkConnectedAccessories() {
        let connectedAccessories = accessoryManager.connectedAccessories
        
        for accessory in connectedAccessories {
            if isSupportedAccessory(accessory) {
                connect(to: accessory)
                break
            }
        }
    }
    
    // MARK: - 设备连接通知
    @objc private func accessoryConnected(_ notification: Notification) {
        guard let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory else { return }
        
        if isSupportedAccessory(accessory) {
            connect(to: accessory)
        }
    }
    
    @objc private func accessoryDisconnected(_ notification: Notification) {
        guard let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory else { return }
        
        if accessory == connectedAccessory {
            disconnect()
        }
    }
    
    // MARK: - 设备支持检测
    private func isSupportedAccessory(_ accessory: EAAccessory) -> Bool {
        // 检查厂商是否为大疆
        let manufacturer = accessory.manufacturer.lowercased()
        let isDJI = manufacturer.contains("dji") || 
                     manufacturer.contains("大疆") ||
                     manufacturer.contains("quectel") ||
                     manufacturer.contains("移远")
        
        // 检查是否支持我们需要的协议
        let hasSupportedProtocol = accessory.protocolStrings.contains { protocolString in
            supportedProtocols.contains { $0.lowercased() == protocolString.lowercased() }
        }
        
        return isDJI || hasSupportedProtocol
    }
    
    // MARK: - 连接设备
    private func connect(to accessory: EAAccessory) {
        // 找到匹配的协议
        guard let protocolString = accessory.protocolStrings.first(where: { protocolString in
            supportedProtocols.contains { $0.lowercased() == protocolString.lowercased() }
        }) ?? accessory.protocolStrings.first else {
            connectionError = USBError.noSupportedProtocol
            return
        }
        
        do {
            session = EASession(accessory: accessory, forProtocol: protocolString)
            
            guard let session = session else {
                connectionError = USBError.sessionCreationFailed
                return
            }
            
            inputStream = session.inputStream
            outputStream = session.outputStream
            
            // 配置流
            inputStream?.delegate = self
            outputStream?.delegate = self
            inputStream?.schedule(in: .main, forMode: .default)
            outputStream?.schedule(in: .main, forMode: .default)
            inputStream?.open()
            outputStream?.open()
            
            connectedAccessory = accessory
            isConnected = true
            connectionError = nil
            onConnectionStateChanged?(true)
            
            print("[USB] 已连接到设备: \(accessory.name), 协议: \(protocolString)")
        }
    }
    
    // MARK: - 断开连接
    private func disconnect() {
        inputStream?.close()
        outputStream?.close()
        inputStream?.remove(from: .main, forMode: .default)
        outputStream?.remove(from: .main, forMode: .default)
        inputStream = nil
        outputStream = nil
        session = nil
        
        connectedAccessory = nil
        isConnected = false
        receiveBuffer.removeAll()
        
        onConnectionStateChanged?(false)
        print("[USB] 设备已断开连接")
    }
    
    // MARK: - 发送数据
    func send(data: Data) -> Bool {
        guard isConnected, let outputStream = outputStream else {
            return false
        }
        
        let bytesWritten = outputStream.write(data.bytes, maxLength: data.count)
        return bytesWritten == data.count
    }
    
    func send(command: String) -> Bool {
        guard let data = (command + "\r\n").data(using: .utf8) else {
            return false
        }
        return send(data: data)
    }
    
    // MARK: - 读取数据
    func readAvailableData() -> Data? {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        guard !receiveBuffer.isEmpty else { return nil }
        let data = receiveBuffer
        receiveBuffer.removeAll()
        return data
    }
    
    // MARK: - 错误类型
    enum USBError: LocalizedError {
        case noSupportedProtocol
        case sessionCreationFailed
        case streamError
        case deviceNotFound
        
        var errorDescription: String? {
            switch self {
            case .noSupportedProtocol:
                return "设备不支持所需的通信协议"
            case .sessionCreationFailed:
                return "创建通信会话失败"
            case .streamError:
                return "数据流错误"
            case .deviceNotFound:
                return "未找到设备"
            }
        }
    }
}

// MARK: - StreamDelegate
extension USBCommunicationManager: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            if aStream == inputStream {
                readFromInputStream()
            }
        case .hasSpaceAvailable:
            // 输出流有空间可写
            break
        case .errorOccurred:
            print("[USB] 流错误: \(aStream.streamError?.localizedDescription ?? "未知错误")")
            connectionError = aStream.streamError
        case .endEncountered:
            print("[USB] 流结束")
            disconnect()
        default:
            break
        }
    }
    
    private func readFromInputStream() {
        guard let inputStream = inputStream else { return }
        
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        
        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(&buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                let data = Data(bytes: buffer, count: bytesRead)
                bufferLock.lock()
                receiveBuffer.append(data)
                bufferLock.unlock()
                onDataReceived?(data)
            } else if bytesRead < 0 {
                print("[USB] 读取错误")
                break
            }
        }
    }
}

// MARK: - Data 扩展
private extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}
