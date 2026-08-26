import Foundation
import Combine
import UserNotifications
import AVFoundation

// MARK: - 通话管理器
final class CallManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = CallManager()
    
    // MARK: - 发布属性
    @Published private(set) var callState: CallState = .idle
    @Published private(set) var callRecords: [CallRecord] = []
    @Published private(set) var callDuration: TimeInterval = 0
    @Published private(set) var isMuted = false
    @Published private(set) var isSpeakerOn = false
    @Published private(set) var isDTMFEnabled = true
    
    // MARK: - 私有属性
    private let atManager = ATCommandManager.shared
    private let userDefaults = UserDefaults.standard
    private var callTimer: Timer?
    private var audioSession: AVAudioSession?
    
    // MARK: - 初始化
    private init() {
        loadCallRecords()
        setupCallbacks()
        configureAudioSession()
    }
    
    // MARK: - 设置回调
    private func setupCallbacks() {
        atManager.onIncomingCall = { [weak self] phoneNumber in
            self?.handleIncomingCall(phoneNumber: phoneNumber)
        }
    }
    
    // MARK: - 配置音频会话
    private func configureAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession?.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession?.setActive(true)
        } catch {
            print("[Call] 音频会话配置失败: \(error)")
        }
    }
    
    // MARK: - 拨号
    func dial(number: String) {
        guard case .idle = callState else { return }
        
        callState = .dialing(number: number)
        
        Task {
            do {
                try await atManager.dial(number: number)
                await MainActor.run {
                    self.callState = .connecting(number: number)
                }
                // 等待通话接通（实际应该监听模块状态）
                try await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.startCall(number: number)
                }
            } catch {
                await MainActor.run {
                    self.callState = .ended(reason: .failed)
                    self.addCallRecord(phoneNumber: number, callType: .outgoing, duration: 0, isMissed: false)
                }
            }
        }
    }
    
    // MARK: - 接听
    func answer() {
        guard case .incoming(let number, let contactName) = callState else { return }
        
        Task {
            do {
                try await atManager.answer()
                await MainActor.run {
                    self.startCall(number: number)
                }
            } catch {
                print("[Call] 接听失败: \(error)")
            }
        }
    }
    
    // MARK: - 拒接
    func reject() {
        guard case .incoming(let number, _) = callState else { return }
        
        Task {
            try? await atManager.hangup()
            await MainActor.run {
                self.callState = .ended(reason: .rejected)
                self.addCallRecord(phoneNumber: number, callType: .missed, duration: 0, isMissed: true)
            }
        }
    }
    
    // MARK: - 挂断
    func hangup() {
        guard case .active(let number, let duration, _, _) = callState else {
            // 非通话中也尝试发送挂断指令
            Task { try? await atManager.hangup() }
            callState = .ended(reason: .normal)
            return
        }
        
        Task {
            try? await atManager.hangup()
            await MainActor.run {
                self.stopCall()
                self.callState = .ended(reason: .normal)
                self.addCallRecord(phoneNumber: number, callType: .outgoing, duration: duration, isMissed: false)
            }
        }
    }
    
    // MARK: - 处理来电
    private func handleIncomingCall(phoneNumber: String) {
        guard case .idle = callState else { return }
        
        callState = .incoming(number: phoneNumber, contactName: nil)
        showIncomingCallNotification(phoneNumber: phoneNumber)
        
        // 自动接听（如果启用）
        if userDefaults.bool(forKey: UserDefaultsKeys.autoAnswer) {
            let delay = userDefaults.double(forKey: UserDefaultsKeys.autoAnswerDelay)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                if case .incoming = self?.callState {
                    self?.answer()
                }
            }
        }
    }
    
    // MARK: - 开始通话计时
    private func startCall(number: String) {
        callDuration = 0
        callState = .active(number: number, duration: 0, isMuted: isMuted, isSpeaker: isSpeakerOn)
        
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if case .active(let number, _, let muted, let speaker) = self.callState {
                self.callDuration += 1
                self.callState = .active(number: number, duration: self.callDuration, isMuted: muted, isSpeaker: speaker)
            }
        }
        
        // 激活音频会话
        do {
            try audioSession?.setActive(true)
        } catch {
            print("[Call] 激活音频会话失败: \(error)")
        }
    }
    
    // MARK: - 停止通话计时
    private func stopCall() {
        callTimer?.invalidate()
        callTimer = nil
        callDuration = 0
        
        do {
            try audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[Call] 停用音频会话失败: \(error)")
        }
    }
    
    // MARK: - 静音切换
    func toggleMute() {
        isMuted.toggle()
        if case .active(let number, let duration, _, let speaker) = callState {
            callState = .active(number: number, duration: duration, isMuted: isMuted, isSpeaker: speaker)
        }
    }
    
    // MARK: - 扬声器切换
    func toggleSpeaker() {
        isSpeakerOn.toggle()
        if case .active(let number, let duration, let muted, _) = callState {
            callState = .active(number: number, duration: duration, isMuted: muted, isSpeaker: isSpeakerOn)
        }
        
        do {
            if isSpeakerOn {
                try audioSession?.overrideOutputAudioPort(.speaker)
            } else {
                try audioSession?.overrideOutputAudioPort(.none)
            }
        } catch {
            print("[Call] 切换扬声器失败: \(error)")
        }
    }
    
    // MARK: - 发送 DTMF
    func sendDTMF(_ digit: String) {
        guard isDTMFEnabled, case .active = callState else { return }
        
        Task {
            try? await atManager.sendDTMF(digit)
        }
    }
    
    // MARK: - 显示来电通知
    private func showIncomingCallNotification(phoneNumber: String) {
        let content = UNMutableNotificationContent()
        content.title = "来电"
        content.body = phoneNumber.formattedPhoneNumber
        content.sound = .default
        content.categoryIdentifier = "INCOMING_CALL"
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - 通话记录管理
    private func loadCallRecords() {
        guard let data = userDefaults.data(forKey: UserDefaultsKeys.callRecords),
              let records = try? JSONDecoder().decode([CallRecord].self, from: data) else {
            return
        }
        callRecords = records
    }
    
    private func saveCallRecords() {
        if let data = try? JSONEncoder().encode(callRecords) {
            userDefaults.set(data, forKey: UserDefaultsKeys.callRecords)
        }
    }
    
    private func addCallRecord(phoneNumber: String, callType: CallRecord.CallType, duration: TimeInterval, isMissed: Bool) {
        let record = CallRecord(
            phoneNumber: phoneNumber,
            timestamp: Date(),
            duration: duration,
            callType: callType,
            isMissed: isMissed
        )
        callRecords.insert(record, at: 0)
        if callRecords.count > 500 {
            callRecords.removeLast()
        }
        saveCallRecords()
    }
    
    func deleteCallRecord(_ record: CallRecord) {
        callRecords.removeAll { $0.id == record.id }
        saveCallRecords()
    }
    
    func clearCallRecords() {
        callRecords.removeAll()
        saveCallRecords()
    }
    
    // MARK: - 格式化通话时长
    var formattedCallDuration: String {
        let minutes = Int(callDuration) / 60
        let seconds = Int(callDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
