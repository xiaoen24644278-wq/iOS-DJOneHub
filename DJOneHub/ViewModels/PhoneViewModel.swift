import Foundation
import Combine

// MARK: - 电话视图模型
final class PhoneViewModel: ObservableObject {
    
    // MARK: - 发布属性
    @Published var dialedNumber = ""
    @Published var callRecords: [CallRecord] = []
    @Published var callState: CallState = .idle
    @Published var callDuration: TimeInterval = 0
    @Published var isMuted = false
    @Published var isSpeakerOn = false
    @Published var showCallHistory = false
    
    // MARK: - 服务引用
    private let callManager = CallManager.shared
    private let contactManager = ContactManager.shared
    
    // MARK: - 取消包
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    init() {
        setupBindings()
    }
    
    // MARK: - 绑定
    private func setupBindings() {
        callManager.$callRecords
            .receive(on: DispatchQueue.main)
            .assign(to: &$callRecords)
        
        callManager.$callState
            .receive(on: DispatchQueue.main)
            .assign(to: &$callState)
        
        callManager.$callDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$callDuration)
        
        callManager.$isMuted
            .receive(on: DispatchQueue.main)
            .assign(to: &$isMuted)
        
        callManager.$isSpeakerOn
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSpeakerOn)
    }
    
    // MARK: - 拨号操作
    func appendDigit(_ digit: String) {
        guard dialedNumber.count < 20 else { return }
        dialedNumber.append(digit)
    }
    
    func deleteLastDigit() {
        guard !dialedNumber.isEmpty else { return }
        dialedNumber.removeLast()
    }
    
    func clearDialedNumber() {
        dialedNumber = ""
    }
    
    func call() {
        guard !dialedNumber.isEmpty else { return }
        callManager.dial(number: dialedNumber)
    }
    
    func callNumber(_ number: String) {
        dialedNumber = number
        callManager.dial(number: number)
    }
    
    // MARK: - 通话操作
    func answer() {
        callManager.answer()
    }
    
    func reject() {
        callManager.reject()
    }
    
    func hangup() {
        callManager.hangup()
    }
    
    func toggleMute() {
        callManager.toggleMute()
    }
    
    func toggleSpeaker() {
        callManager.toggleSpeaker()
    }
    
    func sendDTMF(_ digit: String) {
        callManager.sendDTMF(digit)
    }
    
    // MARK: - 通话记录
    func deleteCallRecord(_ record: CallRecord) {
        callManager.deleteCallRecord(record)
    }
    
    func clearCallRecords() {
        callManager.clearCallRecords()
    }
    
    // MARK: - 辅助方法
    func contactName(for number: String) -> String {
        contactManager.displayName(forPhoneNumber: number)
    }
    
    var formattedCallDuration: String {
        callManager.formattedCallDuration
    }
    
    var isInCall: Bool {
        if case .active = callState { return true }
        if case .dialing = callState { return true }
        if case .connecting = callState { return true }
        if case .incoming = callState { return true }
        return false
    }
}
