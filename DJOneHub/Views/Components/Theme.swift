import SwiftUI

// MARK: - 极简设计系统
/// 统一的简洁风格：留白、细线、单一主色、无装饰
enum Theme {

    /// 主色：沉稳蓝（代替系统默认）
    static let accent = Color(red: 0.20, green: 0.48, blue: 0.96)

    /// 功能色（低饱和）
    static let success = Color(red: 0.22, green: 0.66, blue: 0.42)
    static let danger  = Color(red: 0.86, green: 0.32, blue: 0.30)
    static let warning = Color(red: 0.92, green: 0.66, blue: 0.18)

    /// 间距
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    /// 圆角
    enum Radius {
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 18
    }

    /// 字体（极简：标题粗体、正文常规、辅助小号灰字）
    enum Typo {
        static let largeTitle = Font.system(size: 32, weight: .bold, design: .rounded)
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 16, weight: .semibold)
        static let body = Font.system(size: 15)
        static let caption = Font.system(size: 13)
        static let mono = Font.system(size: 13, design: .monospaced)
    }
}

// MARK: - 极简卡片
struct MinimalCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Theme.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(white: 0.14)
            : Color(white: 0.96)
    }
}

// MARK: - 极简列表分组
struct MinimalSection<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if let title = title {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, Theme.Space.xs)
            }
            content
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        }
    }
}

// MARK: - 状态点
struct StatusDot: View {
    enum State {
        case ok, warn, bad, idle

        var color: Color {
            switch self {
            case .ok: return Theme.success
            case .warn: return Theme.warning
            case .bad: return Theme.danger
            case .idle: return Color.secondary.opacity(0.4)
            }
        }
    }

    let state: State
    var body: some View {
        Circle()
            .fill(state.color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - 主按钮
struct PrimaryButton: View {
    let title: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 20)
                } else {
                    Text(title)
                        .font(Theme.Typo.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .background(Theme.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
