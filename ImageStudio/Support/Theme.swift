import SwiftUI

extension Color {
    /// 品牌强调色：暗房琥珀。深色下亮铜、浅色下深琥珀（对比达标）。
    static let brand = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.93, green: 0.66, blue: 0.32, alpha: 1)
            : NSColor(red: 0.68, green: 0.42, blue: 0.12, alpha: 1)
    })

    /// 画廊底：比窗口底深一档，衬托图片（用色差替代分割线）。
    static let canvas = Color(nsColor: .underPageBackgroundColor)
}

/// 可点元素统一反馈：hover 背景加深 + 手型指针。
struct HoverHighlight: ViewModifier {
    var cornerRadius: CGFloat = 8
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.primary.opacity(hovering ? 0.08 : 0))
            )
            .animation(.easeOut(duration: 0.12), value: hovering)
            .onHover { hovering = $0 }
            .pointerStyle(.link)
    }
}

extension View {
    func hoverHighlight(cornerRadius: CGFloat = 8) -> some View {
        modifier(HoverHighlight(cornerRadius: cornerRadius))
    }
}
