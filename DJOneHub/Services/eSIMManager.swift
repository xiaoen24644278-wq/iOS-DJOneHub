import Foundation
import Combine

// 类型别名，避免属性名与类型名冲突导致循环引用
typealias EStatus = eSIMStatus

// MARK: - eSIM / eUICC 管理器
final class eSIMManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = eSIMManager()
    
    // MARK: - 发布属性
    @Published private(set) var eSIMStatus: eSIMStatus = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var isProcessing = false
    
    // MARK: - 私有属性
    private let atManager = ATCommandManager.shared
    
    // MARK: - 初始化
    private init() {}
    
    // MARK: - 读取 eSIM 信息
    func refreshInfo() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            var status: eSIMStatus = .empty
            
            // 读取 EID
            let eidResponse = try await atManager.sendCommand("AT+EID?")
            if let match = eidResponse.range(of: #"[0-9A-Fa-f]{32}"#, options: .regularExpression) {
                status.eid = String(eidResponse[match])
            }
            
            // 读取 Profile 列表
            let profilesResponse = try await atManager.sendCommand("AT+QCPROF?")
            status.profiles = parseProfiles(profilesResponse)
            
            await MainActor.run {
                self.eSIMStatus = status
            }
        } catch {
            print("[eSIM] 读取信息失败: \(error)")
        }
    }
    
    // MARK: - 下载 Profile
    func downloadProfile(activationCode: String, confirmationCode: String? = nil) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        // LPA: 下载 Profile
        var command = "AT+QPLMN=1,\"\(activationCode)\""
        if let code = confirmationCode {
            command += ",\"\(code)\""
        }
        
        _ = try await atManager.sendCommand(command)
        
        // 等待下载完成
        try await Task.sleep(nanoseconds: 10_000_000_000)
        
        await refreshInfo()
    }
    
    // MARK: - 启用 Profile
    func enableProfile(iccid: String) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        _ = try await atManager.sendCommand("AT+QCPROF=1,\"\(iccid)\"")
        try await Task.sleep(nanoseconds: 3_000_000_000)
        await refreshInfo()
    }
    
    // MARK: - 禁用 Profile
    func disableProfile(iccid: String) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        _ = try await atManager.sendCommand("AT+QCPROF=0,\"\(iccid)\"")
        try await Task.sleep(nanoseconds: 3_000_000_000)
        await refreshInfo()
    }
    
    // MARK: - 删除 Profile
    func deleteProfile(iccid: String) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        _ = try await atManager.sendCommand("AT+QCPROF=2,\"\(iccid)\"")
        try await Task.sleep(nanoseconds: 5_000_000_000)
        await refreshInfo()
    }
    
    // MARK: - 重命名 Profile
    func renameProfile(iccid: String, newName: String) async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        _ = try await atManager.sendCommand("AT+QCPROF=3,\"\(iccid)\",\"\(newName)\"")
        await refreshInfo()
    }
    
    // MARK: - 解析 Profile 列表
    private func parseProfiles(_ response: String) -> [EStatus.eSIMProfile] {
        var profiles: [EStatus.eSIMProfile] = []
        
        let lines = response.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("+QCPROF:") {
                // 格式: +QCPROF: <state>,<iccid>,<profile_name>,<provider_name>
                let components = trimmed.components(separatedBy: ",")
                if components.count >= 4 {
                    let stateStr = components[0].replacingOccurrences(of: "+QCPROF:", with: "").trimmingCharacters(in: .whitespaces)
                    let iccid = components[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                    let name = components[2].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                    let provider = components[3].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                    
                    let state: EStatus.eSIMProfile.ProfileState
                    switch stateStr {
                    case "1": state = .enabled
                    case "0": state = .disabled
                    default: state = .disabled
                    }
                    
                    let profile = EStatus.eSIMProfile(
                        id: iccid,
                        iccid: iccid,
                        name: name,
                        providerName: provider,
                        state: state,
                        isEnabled: state == .enabled
                    )
                    profiles.append(profile)
                }
            }
        }
        
        return profiles
    }
}
