import SwiftUI

// MARK: - Toolbar 扩展，解决 Xcode 16 中 toolbar(content:) 歧义问题
extension View {
    /// 明确使用 @ToolbarContentBuilder 的 toolbar 方法
    /// 避免 Xcode 16 中 toolbar(content:) 的 @ViewBuilder 和 @ToolbarContentBuilder 重载歧义
    func myToolbar<ToolbarContent: SwiftUI.ToolbarContent>(
        @ToolbarContentBuilder content: () -> ToolbarContent
    ) -> some View {
        self.toolbar(content: content())
    }
}
