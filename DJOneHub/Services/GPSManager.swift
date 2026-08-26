import Foundation
import Combine
import CoreLocation

// MARK: - GPS 管理器
final class GPSManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = GPSManager()
    
    // MARK: - 发布属性
    @Published private(set) var gpsStatus = GPSStatus.disabled
    @Published private(set) var isUpdating = false
    
    // MARK: - 私有属性
    private let atManager = ATCommandManager.shared
    private let userDefaults = UserDefaults.standard
    private var updateTimer: Timer?
    
    // MARK: - 初始化
    private init() {
        if userDefaults.bool(forKey: UserDefaultsKeys.gpsEnabled) {
            // 不自动启用，等待用户确认
        }
    }
    
    // MARK: - 启用 GPS
    func enableGPS() async {
        do {
            try await atManager.enableGPS()
            
            await MainActor.run {
                self.gpsStatus.isEnabled = true
                self.userDefaults.set(true, forKey: UserDefaultsKeys.gpsEnabled)
                self.startUpdating()
            }
        } catch {
            print("[GPS] 启用失败: \(error)")
        }
    }
    
    // MARK: - 禁用 GPS
    func disableGPS() async {
        do {
            try await atManager.disableGPS()
            
            await MainActor.run {
                self.stopUpdating()
                self.gpsStatus = .disabled
                self.userDefaults.set(false, forKey: UserDefaultsKeys.gpsEnabled)
            }
        } catch {
            print("[GPS] 禁用失败: \(error)")
        }
    }
    
    // MARK: - 开始更新位置
    private func startUpdating() {
        stopUpdating()
        
        let interval = userDefaults.double(forKey: UserDefaultsKeys.gpsUpdateInterval)
        let timeInterval = interval > 0 ? interval : 5.0
        
        DispatchQueue.main.async {
            self.updateTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] _ in
                Task {
                    await self?.updatePosition()
                }
            }
        }
        
        // 立即更新一次
        Task {
            await updatePosition()
        }
    }
    
    // MARK: - 停止更新
    private func stopUpdating() {
        updateTimer?.invalidate()
        updateTimer = nil
        isUpdating = false
    }
    
    // MARK: - 更新位置
    private func updatePosition() async {
        guard gpsStatus.isEnabled else { return }
        
        isUpdating = true
        defer { isUpdating = false }
        
        do {
            if let position = try await atManager.getGPSPosition() {
                await MainActor.run {
                    self.gpsStatus.latitude = position.lat
                    self.gpsStatus.longitude = position.lon
                    self.gpsStatus.altitude = position.alt
                    self.gpsStatus.timestamp = Date()
                    self.gpsStatus.fixQuality = .gpsFix
                }
            }
        } catch {
            print("[GPS] 更新位置失败: \(error)")
        }
    }
    
    // MARK: - 获取 NMEA 语句
    func getNMEASentence(_ type: String) async throws -> String {
        return try await atManager.sendCommand("AT+QGPSLOC?")
    }
    
    // MARK: - 格式化坐标
    var formattedCoordinates: String {
        guard let lat = gpsStatus.latitude, let lon = gpsStatus.longitude else {
            return "未定位"
        }
        return String(format: "%.6f, %.6f", lat, lon)
    }
    
    var formattedAltitude: String {
        guard let alt = gpsStatus.altitude else { return "-" }
        return String(format: "%.1f 米", alt)
    }
}
