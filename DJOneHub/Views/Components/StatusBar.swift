import SwiftUI

// MARK: - 信号强度指示器
struct SignalIndicator: View {
    let bars: Int
    let maxBars: Int = 4
    let isConnected: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<maxBars, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color(for: index))
                    .frame(width: 3, height: height(for: index))
            }
        }
        .frame(height: 16)
    }
    
    private func height(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [6, 9, 12, 15]
        return heights[index]
    }
    
    private func color(for index: Int) -> Color {
        guard isConnected else { return .gray.opacity(0.3) }
        return index < bars ? .accentColor : .gray.opacity(0.3)
    }
}

// MARK: - 网络类型指示器
struct NetworkIndicator: View {
    let networkType: ModuleStatus.NetworkType
    let isConnected: Bool
    
    var body: some View {
        Text(displayText)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isConnected ? .accentColor : .gray)
    }
    
    private var displayText: String {
        switch networkType {
        case .lte: return "4G"
        case .nr: return "5G"
        case .umts, .hsdpa, .hsupa: return "3G"
        case .gsm, .edge: return "2G"
        case .noService: return "无服务"
        default: return "-"
        }
    }
}

// MARK: - 状态栏（顶部状态显示）
struct StatusBar: View {
    let moduleStatus: ModuleStatus
    let networkStatus: NetworkStatus
    
    var body: some View {
        HStack(spacing: 12) {
            // 连接状态
            HStack(spacing: 4) {
                Circle()
                    .fill(moduleStatus.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(moduleStatus.isConnected ? "已连接" : "未连接")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 运营商
            if !moduleStatus.operatorName.isEmpty && moduleStatus.operatorName != "-" {
                Text(moduleStatus.operatorName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // 网络类型
            NetworkIndicator(networkType: moduleStatus.networkType, isConnected: moduleStatus.isConnected)
            
            // 信号强度
            SignalIndicator(bars: moduleStatus.signalBars, isConnected: moduleStatus.isConnected)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.95))
    }
}

// MARK: - 自适应布局容器（iPad 横竖屏适配）
struct AdaptiveLayoutContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        Group {
            if isLandscape && isPad {
                // iPad 横屏：宽布局
                HStack(spacing: 0) {
                    content
                }
            } else {
                // 竖屏或 iPhone：窄布局
                VStack(spacing: 0) {
                    content
                }
            }
        }
    }
    
    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var isLandscape: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .compact
    }
}

// MARK: - 卡片视图
struct CardView<Content: View>: View {
    let title: String?
    let systemImage: String?
    let content: Content
    
    init(title: String? = nil, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                HStack(spacing: 8) {
                    if let systemImage = systemImage {
                        Image(systemName: systemImage)
                            .foregroundColor(.accentColor)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            content
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 开关行
struct ToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool
    var subtitle: String? = nil
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16))
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
    }
}

// MARK: - 导航行
struct NavigationRow: View {
    let title: String
    let systemImage: String
    var value: String? = nil
    var destination: (() -> AnyView)? = nil
    
    var body: some View {
        if let destination = destination {
            NavigationLink(destination: destination()) {
                rowContent
            }
        } else {
            rowContent
        }
    }
    
    private var rowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16))
            Spacer()
            if let value = value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            if destination != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 分段选择器
struct SegmentedPicker<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String {
    let title: String
    @Binding var selection: T
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Picker(title, selection: $selection) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - 预览
struct Components_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StatusBar(moduleStatus: .disconnected, networkStatus: .disconnected)
                .previewLayout(.sizeThatFits)
            SignalIndicator(bars: 3, isConnected: true)
                .previewLayout(.sizeThatFits)
        }
    }
}
