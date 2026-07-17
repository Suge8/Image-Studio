import SwiftUI
import UniformTypeIdentifiers

struct ComposerView: View {
    @Bindable var store: StudioStore
    @FocusState private var promptFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ProviderCapsule(store: store)
                .padding(.top, 40) // 红绿灯区域
            promptEditor
            referenceZone
            Spacer(minLength: 0)
            chipsRow
            if let reason = store.blockedReason {
                blockedCard(reason)
            }
            generateArea
            HStack {
                Spacer()
                Image("MascotStudio")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 190, maxHeight: 190)
                    .accessibilityHidden(true)
                Spacer()
            }
            bottomBar
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeOut(duration: 0.18), value: store.draft.references.count)
        .onDrop(of: [.fileURL], isTargeted: nil) { handleDrop($0) }
    }

    // MARK: - Prompt

    private var promptEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $store.draft.prompt)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
            if store.draft.prompt.isEmpty {
                Text("Describe the image you want…")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 140, maxHeight: 220)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    promptFocused ? AnyShapeStyle(LinearGradient.brand) : AnyShapeStyle(.quaternary),
                    lineWidth: promptFocused ? 1.5 : 1
                )
        )
        .overlay(alignment: .bottomTrailing) {
            if !store.promptHistory.isEmpty {
                HistoryButton(store: store)
                    .padding(6)
            }
        }
        .focused($promptFocused)
        .animation(.easeOut(duration: 0.15), value: promptFocused)
    }

    // MARK: - 参考图区：空态是整块可点拖放区；有图变缩略网格 + 末尾加号

    private let referenceColumns = [GridItem(.adaptive(minimum: 56, maximum: 64), spacing: 8)]

    @ViewBuilder
    private var referenceZone: some View {
        if store.draft.references.isEmpty {
            Button {
                pickReferences()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title3)
                    Text("Drop, paste, or click to add references")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, minHeight: 88)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
        } else {
            LazyVGrid(columns: referenceColumns, alignment: .leading, spacing: 8) {
                ForEach(store.draft.references) { ref in
                    referenceCell(ref)
                }
                if store.draft.references.count < AppConstants.maxReferences {
                    Button {
                        pickReferences()
                    } label: {
                        Image(systemName: "plus")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 56, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .help(Text("Add reference images (drag in / ⇧⌘V to paste)"))
                }
            }
        }
    }

    private func referenceCell(_ ref: ReferenceImage) -> some View {
        ZStack(alignment: .topTrailing) {
            ReferenceThumb(url: ref.url)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    store.removeReference(ref.id)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .padding(2)
        }
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    // MARK: - 参数 chips

    private var chipsRow: some View {
        HStack(spacing: 8) {
            Chip(icon: "square.grid.2x2", label: String(localized: "\(store.draft.count) images")) {
                countPopover
            }
            Chip(icon: "aspectratio", label: sizeLabel) {
                sizePopover
            }
            if store.draft.provider == .codex {
                Chip(icon: "dial.medium", label: qualityLabel) {
                    qualityPopover
                }
            }
            FavoritesChip(store: store)
        }
    }

    private var sizeLabel: String {
        switch store.draft.provider {
        case .codex:
            store.draft.options.size.label
        case .relay:
            [store.draft.relay.aspect.label, store.draft.relay.imageSize.label]
                .filter { $0 != "auto" }
                .joined(separator: " · ")
                .ifEmpty("auto")
        }
    }

    private var qualityLabel: String {
        let quality = store.draft.options.quality
        let background = store.draft.options.background
        var parts: [String] = []
        if quality != .auto { parts.append(quality.label) }
        if background != .auto { parts.append(background.label) }
        // chips 宽度有限：默认只显 "auto"，icon 已区分语义
        return parts.joined(separator: " · ").ifEmpty("auto")
    }

    private var countPopover: some View {
        Stepper(value: $store.draft.count, in: 1 ... 64) {
            Text("Count: \(store.draft.count)")
                .monospacedDigit()
        }
        .padding(14)
        .frame(width: 190)
        .onChange(of: store.draft.count) { _, _ in store.savePreferences() }
    }

    @ViewBuilder
    private var sizePopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch store.draft.provider {
            case .codex:
                Picker("Size", selection: $store.draft.options.size) {
                    ForEach(ImageSizeOption.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("The Codex endpoint only honors these ratios (verified). Use the relay channel for larger sizes.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            case .relay:
                Picker("Aspect", selection: $store.draft.relay.aspect) {
                    ForEach(RelayAspect.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Resolution", selection: $store.draft.relay.imageSize) {
                    ForEach(RelayImageSize.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Aspect is exact; resolution is approximate and only supported by some models — switch back to auto if generation fails.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 300)
        .onChange(of: store.draft.options.size) { _, _ in store.savePreferences() }
        .onChange(of: store.draft.relay) { _, _ in store.savePreferences() }
    }

    private var qualityPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Quality", selection: $store.draft.options.quality) {
                ForEach(Quality.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Background", selection: $store.draft.options.background) {
                ForEach(BackgroundOption.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .frame(width: 300)
    }

    // MARK: - 生成

    private func blockedCard(_ reason: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.orange)
            Text(reason)
                .font(.callout)
            Spacer()
            switch store.draft.provider {
            case .codex:
                Button("Re-check") {
                    Task { await store.refreshAuth() }
                }
                .controlSize(.small)
            case .relay:
                Button("Settings") { store.showSettings = true }
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.orange.opacity(0.08)))
    }

    /// 生成区：居中胶囊主按钮（进行中仍可提新批次）+ icon-only 停止；状态行居中。
    private var generateArea: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: store.submit) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.callout.weight(.bold))
                        Text("Generate")
                    }
                }
                .buttonStyle(BrandProminentButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canSubmit)
                .pointerStyle(.link)

                if store.run.isBusy {
                    Button {
                        store.cancel()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.quaternary.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .keyboardShortcut(.cancelAction)
                    .help(Text("Stop"))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)

            if store.run.isBusy {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    if case .running(let inFlight, let total) = store.run {
                        Text("Done \(max(0, total - inFlight))/\(total)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            } else if let cost = store.estimatedCost {
                Text(cost)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(.spring(duration: 0.25), value: store.run.isBusy)
    }

    private var bottomBar: some View {
        HStack {
            Button {
                store.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
                    .padding(5)
            }
            .buttonStyle(.plain)
            .hoverHighlight()
            .help(Text("Settings"))
            Spacer()
        }
    }

    private var canSubmit: Bool {
        let hasPrompt = !store.draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasPrompt || !store.draft.references.isEmpty) && store.blockedReason == nil
    }

    // MARK: - 文件

    private func pickReferences() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK else { return }
        store.addReferences(urls: panel.urls)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let lock = NSLock()
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                guard let url else { return }
                lock.lock()
                urls.append(url)
                lock.unlock()
            }
        }
        group.notify(queue: .main) {
            store.addReferences(urls: urls)
        }
        return true
    }
}

// MARK: - 通道胶囊

struct ProviderCapsule: View {
    @Bindable var store: StudioStore
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: store.draft.provider == .codex ? "terminal" : "cloud")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(store.providerLabel)
                    .font(.callout)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9).fill(.quaternary.opacity(0.45)))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .help(Text("Switch generation channel"))
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            popoverContent
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Channel", selection: $store.draft.provider) {
                ForEach(Provider.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch store.draft.provider {
            case .codex:
                LabeledContent("Model", value: store.resolvedCodexModel)
                    .font(.callout)
                Text("Uses your local codex login session")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            case .relay:
                if store.relayConfigured {
                    Picker("Model", selection: $store.draft.relay.model) {
                        ForEach(store.relayModelOptions) { model in
                            if let price = model.priceLabel {
                                Text("\(model.id)  \(price)").tag(model.id)
                            } else {
                                Text(model.id).tag(model.id)
                            }
                        }
                    }
                    .labelsHidden()
                } else {
                    Button("Configure relay…") {
                        showPopover = false
                        store.showSettings = true
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 270)
        .onChange(of: store.draft.provider) { _, _ in store.savePreferences() }
        .onChange(of: store.draft.relay.model) { _, _ in store.savePreferences() }
    }
}

// MARK: - 收藏提示词

private struct FavoritesChip: View {
    @Bindable var store: StudioStore
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: "star")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Capsule().fill(.quaternary.opacity(0.45)))
        }
        .buttonStyle(.plain)
        .hoverHighlight(cornerRadius: 14)
        .help(Text("Favorite prompts"))
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                if store.favorites.isEmpty {
                    Text("No favorites yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(20)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(store.sortedFavorites) { favorite in
                                FavoriteRow(favorite: favorite, store: store) {
                                    store.draft.prompt = favorite.text
                                    showPopover = false
                                }
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 340)
                }
                Divider()
                Button {
                    store.saveCurrentPromptAsFavorite()
                } label: {
                    Label("Save Current Prompt", systemImage: "star.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canSave ? AnyShapeStyle(Color.brand) : AnyShapeStyle(.tertiary))
                .disabled(!canSave)
                .padding(10)
                .pointerStyle(.link)
            }
            .frame(width: 340)
        }
    }

    private var canSave: Bool {
        !store.draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct FavoriteRow: View {
    let favorite: FavoritePrompt
    let store: StudioStore
    let apply: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: apply) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if favorite.pinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.brand)
                        }
                        Text(favorite.title)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                    }
                    Text(favorite.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            if hovering {
                Button {
                    store.togglePin(favorite.id)
                } label: {
                    Image(systemName: favorite.pinned ? "pin.slash" : "pin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .help(favorite.pinned ? Text("Unpin") : Text("Pin"))
                Button {
                    store.removeFavorite(favorite.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .help(Text("Delete"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .hoverHighlight(cornerRadius: 6)
        .onHover { hovering = $0 }
    }
}

// MARK: - Prompt 历史

private struct HistoryButton: View {
    @Bindable var store: StudioStore
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(5)
        }
        .buttonStyle(.plain)
        .hoverHighlight(cornerRadius: 6)
        .help(Text("Prompt history"))
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(store.promptHistory.prefix(20), id: \.self) { prompt in
                            Button {
                                store.draft.prompt = prompt
                                showPopover = false
                            } label: {
                                Text(prompt)
                                    .font(.callout)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .hoverHighlight(cornerRadius: 6)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 320)
                Divider()
                Button("Clear History") {
                    store.promptHistory = []
                    showPopover = false
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .pointerStyle(.link)
            }
            .frame(width: 320)
        }
    }
}

// MARK: - 组件

private struct Chip<Content: View>: View {
    let icon: String
    let label: String
    @ViewBuilder let content: () -> Content
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.callout)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.quaternary.opacity(0.45)))
        }
        .buttonStyle(.plain)
        .hoverHighlight(cornerRadius: 12)
        .popover(isPresented: $showPopover, arrowEdge: .bottom, content: content)
    }
}

private struct ReferenceThumb: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary)
            }
        }
        .task(id: url) {
            image = NSImage(contentsOf: url)
        }
    }
}

extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
