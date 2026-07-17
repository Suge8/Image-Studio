import QuickLook
import SwiftUI

struct GalleryView: View {
    @Bindable var store: StudioStore
    @State private var selectedID: UUID?
    @State private var previewURL: URL?

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 12)]

    var body: some View {
        Group {
            if store.items.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .quickLookPreview($previewURL)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.items) { item in
                    GalleryCell(
                        item: item,
                        store: store,
                        isSelected: selectedID == item.id,
                        select: { selectedID = item.id },
                        preview: { url in previewURL = url }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .animation(.spring(duration: 0.3), value: store.items.map(\.id))
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) {
            guard let id = selectedID,
                  let item = store.items.first(where: { $0.id == id }),
                  case .succeeded(let url) = item.state
            else { return .ignored }
            previewURL = url
            return .handled
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Write a prompt, then ⌘↩ to generate")
                .font(.title3.weight(.medium))
            Text("Results and existing images in the output folder show up here")
                .font(.callout)
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                samplePrompt(String(localized: "An orange cat wearing an astronaut helmet, cinematic lighting, shallow depth of field"))
                samplePrompt(String(localized: "Minimal product poster: a bottle of lime sparkling water floating above water, studio lighting"))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func samplePrompt(_ text: String) -> some View {
        Button {
            store.draft.prompt = text
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "text.cursor")
                    .font(.caption)
                Text(text)
                    .font(.callout)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.quaternary.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .hoverHighlight(cornerRadius: 14)
    }
}

// MARK: - Cell

private struct GalleryCell: View {
    let item: GalleryItem
    let store: StudioStore
    let isSelected: Bool
    let select: () -> Void
    let preview: (URL) -> Void

    @State private var image: NSImage?
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail
            if let caption = statusCaption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .task(id: item.state) {
            if case .succeeded(let url) = item.state {
                image = await store.thumbnail(for: url)
            } else {
                image = nil
            }
        }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(0.4))
            content
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.white.opacity(0.06)),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .scaleEffect(hovering && !reduceMotion ? 1.02 : 1)
        .shadow(color: .black.opacity(hovering ? 0.18 : 0), radius: 8, y: 3)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering = $0 }
        .pointerStyle(.link)
        .help(fileName ?? "")
        .onTapGesture(count: 2) {
            if case .succeeded(let url) = item.state {
                NSWorkspace.shared.open(url)
            }
        }
        .onTapGesture { select() }
        .contextMenu { menu }
    }

    @ViewBuilder
    private var content: some View {
        switch item.state {
        case .queued, .inFlight:
            ZStack {
                if reduceMotion {
                    RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.4))
                } else {
                    Shimmer()
                }
                VStack(spacing: 6) {
                    if item.state == .inFlight {
                        ElapsedLabel(since: item.createdAt)
                    } else {
                        Text("Queued")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .succeeded(let url):
            if let image {
                SucceededImage(image: image, reduceMotion: reduceMotion)
                    .draggable(url)
                    .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
            } else {
                ProgressView().controlSize(.small)
            }
        case .failed(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .lineLimit(3)
                if canRetry {
                    Button("Retry") { store.retrySlot(item) }
                        .controlSize(.small)
                        .pointerStyle(.link)
                }
            }
        }
    }

    @ViewBuilder
    private var menu: some View {
        if case .succeeded(let url) = item.state {
            Button("Preview") { preview(url) }
            Button("Open") { NSWorkspace.shared.open(url) }
            Button("Show in Finder") { store.reveal(url) }
            Divider()
            Button("Use as Reference") { store.useAsReference(url) }
            Button("Copy Image") { store.copyImage(url) }
            Divider()
            Button("Move to Trash", role: .destructive) { store.deleteFile(url) }
        } else if canRetry {
            Button("Retry") { store.retrySlot(item) }
        }
    }

    private var canRetry: Bool {
        if case .failed = item.state, case .session = item.source { return true }
        return false
    }

    /// 成功项不显示文字（文件名收进 hover tooltip），画廊只留图。
    private var statusCaption: String? {
        switch item.state {
        case .queued: String(localized: "Queued")
        case .inFlight: String(localized: "Generating")
        case .succeeded: nil
        case .failed: String(localized: "Failed")
        }
    }

    private var fileName: String? {
        if case .succeeded(let url) = item.state { return url.lastPathComponent }
        return nil
    }
}

/// 完成图弹入：opacity + 轻微 scale（200ms 缓出）。
private struct SucceededImage: View {
    let image: NSImage
    let reduceMotion: Bool
    @State private var appeared = false

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.96)
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { appeared = true }
                }
            }
    }
}

/// 生成中的已耗时（progress 字段实测不可靠，诚实显示耗时）。
private struct ElapsedLabel: View {
    let since: Date

    var body: some View {
        TimelineView(.periodic(from: since, by: 1)) { context in
            let seconds = max(0, Int(context.date.timeIntervalSince(since)))
            Text("\(seconds)s")
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }
}

/// 骨架微光（等待即语义，唯一循环动画）。
private struct Shimmer: View {
    @State private var phase: CGFloat = -1.5

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, .white.opacity(0.12), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 1.5)
            .offset(x: phase * geo.size.width)
        }
        .background(.quaternary.opacity(0.4))
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}
