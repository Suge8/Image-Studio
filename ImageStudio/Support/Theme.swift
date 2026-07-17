import SwiftUI

extension Color {
    /// 品牌主色：珊瑚（单色场合用它：图标 tint、pin、选中框）。
    static let brand = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.96, green: 0.52, blue: 0.42, alpha: 1)
            : NSColor(red: 0.85, green: 0.38, blue: 0.30, alpha: 1)
    })

}

extension LinearGradient {
    /// 品牌渐变：柔和多彩（珊瑚→玫瑰→紫罗兰→天青），Apple Intelligence 风的原生多彩语言；
    /// 饱和度压到中档避免霓虹 AI 味。用于主 CTA 与 focus ring；小元素用单色 brand。
    static let brand = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.55, blue: 0.42),  // 珊瑚
            Color(red: 0.91, green: 0.45, blue: 0.62),  // 玫瑰
            Color(red: 0.62, green: 0.47, blue: 0.90),  // 紫罗兰
            Color(red: 0.38, green: 0.62, blue: 0.94),  // 天青
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// 品牌主按钮：胶囊渐变底、白字、自适应宽度；禁用降灰；按压微缩。
struct BrandProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? .white : .secondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isEnabled ? AnyShapeStyle(LinearGradient.brand) : AnyShapeStyle(.quaternary))
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 生成中骨架：品牌渐变呼吸 + 流光扫过（等待即语义，唯一循环动画）。
struct GenerativeShimmer: View {
    @State private var sweep = false
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LinearGradient.brand
            .opacity(reduceMotion ? 0.22 : (breathe ? 0.30 : 0.16))
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 1.6)
                        .offset(x: sweep ? geo.size.width : -geo.size.width * 1.6)
                        .blendMode(.plusLighter)
                    }
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    sweep = true
                }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
    }
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
