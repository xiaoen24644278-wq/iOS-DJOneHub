import SwiftUI
import MapKit

// MARK: - GPS 状态视图
struct GPSStatusView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    var body: some View {
        List {
            // GPS 开关
            Section {
                ToggleRow(
                    title: "GPS 定位",
                    systemImage: "location.fill",
                    isOn: Binding(
                        get: { viewModel.gpsStatus.isEnabled },
                        set: { _ in
                            Task {
                                await viewModel.toggleGPS()
                            }
                        }
                    ),
                    subtitle: "启用模块内置 GPS 定位"
                )
            }
            
            if viewModel.gpsStatus.isEnabled {
                // 地图
                Section {
                    Map(coordinateRegion: $region, showsUserLocation: false, annotationItems: annotationItems) { item in
                        MapPin(coordinate: item.coordinate, tint: .accentColor)
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                    .listRowInsets(EdgeInsets())
                }
                .listRowBackground(Color.clear)
                
                // 位置信息
                Section("位置信息") {
                    InfoRow(title: "纬度", value: latitudeString)
                    InfoRow(title: "经度", value: longitudeString)
                    InfoRow(title: "海拔", value: viewModel.gpsManager.formattedAltitude)
                    InfoRow(title: "速度", value: speedString)
                    InfoRow(title: "航向", value: courseString)
                }
                
                // 卫星信息
                Section("卫星信息") {
                    InfoRow(title: "可见卫星", value: "\(viewModel.gpsStatus.satellitesInView)")
                    InfoRow(title: "使用卫星", value: "\(viewModel.gpsStatus.satellitesInUse)")
                    InfoRow(title: "定位质量", value: fixQualityString)
                    InfoRow(title: "更新时间", value: updateTimeString)
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "GPS 未启用",
                        systemImage: "location.slash",
                        description: Text("启用 GPS 后可查看模块定位信息")
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("GPS 定位")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.gpsStatus.latitude) { newValue in
            if let lat = newValue, let lon = viewModel.gpsStatus.longitude {
                region.center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
    }
    
    private var annotationItems: [MapAnnotationItem] {
        guard let lat = viewModel.gpsStatus.latitude,
              let lon = viewModel.gpsStatus.longitude else {
            return []
        }
        return [MapAnnotationItem(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))]
    }
    
    private var latitudeString: String {
        guard let lat = viewModel.gpsStatus.latitude else { return "-" }
        return String(format: "%.6f°", lat)
    }
    
    private var longitudeString: String {
        guard let lon = viewModel.gpsStatus.longitude else { return "-" }
        return String(format: "%.6f°", lon)
    }
    
    private var speedString: String {
        guard let speed = viewModel.gpsStatus.speed else { return "-" }
        return String(format: "%.1f km/h", speed * 3.6)
    }
    
    private var courseString: String {
        guard let course = viewModel.gpsStatus.course else { return "-" }
        return String(format: "%.1f°", course)
    }
    
    private var fixQualityString: String {
        switch viewModel.gpsStatus.fixQuality {
        case .noFix: return "无定位"
        case .gpsFix: return "GPS 定位"
        case .dgpsFix: return "DGPS 定位"
        case .ppsFix: return "PPS 定位"
        case .rtkFixed: return "RTK 固定"
        case .rtkFloat: return "RTK 浮动"
        case .estimated: return "估算"
        case .manual: return "手动"
        case .simulation: return "模拟"
        }
    }
    
    private var updateTimeString: String {
        guard let time = viewModel.gpsStatus.timestamp else { return "-" }
        return DateFormatter.fullDateTime.string(from: time)
    }
}

// MARK: - 地图标注项
struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - 关于视图
struct AboutView: View {
    var body: some View {
        List {
            // App 信息
            Section {
                VStack(spacing: 12) {
                    // App 图标
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("DJOneHub")
                        .font(.system(size: 22, weight: .bold))
                    
                    Text("版本 1.0.0")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .listRowBackground(Color.clear)
            
            // 项目介绍
            Section("关于") {
                Text("DJOneHub 是一个非官方开源项目，让大疆第一代 4G 模块成为 iPhone / iPad 上长期可用的实体 SIM 终端。")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Link(destination: URL(string: "https://github.com/rogerbush007-a11y/DJOneHub-mac-enhanced")!) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundColor(.accentColor)
                        Text("GitHub 项目")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 功能
            Section("功能") {
                FeatureRow(icon: "phone.fill", title: "电话", description: "拨号、接听、挂断、DTMF、通话记录")
                FeatureRow(icon: "message.fill", title: "短信", description: "收发短信、验证码预览、自动清理")
                FeatureRow(icon: "person.2.fill", title: "通讯录", description: "同步本机联系人、快速拨号发短信")
                FeatureRow(icon: "network", title: "4G 上网", description: "USB 网络共享、流量统计")
                FeatureRow(icon: "location.fill", title: "GPS 定位", description: "模块内置 GPS 位置读取")
                FeatureRow(icon: "simcard.fill", title: "eSIM 管理", description: "eUICC Profile 下载、启用、删除")
                FeatureRow(icon: "terminal.fill", title: "AT 控制台", description: "直接发送 AT 指令调试模块")
            }
            
            // 开源声明
            Section("开源声明") {
                Text("本项目基于 PolyForm Noncommercial License 1.0.0 开源，仅允许非商业用途。")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Text("大疆、DJI 等商标归各自权利人所有。本项目不代表 DJI 官方。")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            // 致谢
            Section("致谢") {
                Text("感谢原 VoHive 项目及作者 iniwex5、libusb 及其他开源组件贡献者。")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 功能行
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 预览
struct GPSStatusView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            GPSStatusView(viewModel: SettingsViewModel())
        }
    }
}
