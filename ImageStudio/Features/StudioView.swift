import SwiftUI
import UniformTypeIdentifiers

struct StudioView: View {
    @Bindable var store: StudioStore
    @State private var pasteMonitorInstalled = false

    var body: some View {
        HStack(spacing: 0) {
            ComposerView(store: store)
                .frame(width: 340)
            GalleryView(store: store)
        }
        .background(.background)
        .ignoresSafeArea()
        .overlay(alignment: .top) { toastView }
        .animation(.spring(duration: 0.3), value: store.toast)
        .sheet(isPresented: $store.showSettings) {
            SettingsView(store: store)
        }
        .sheet(isPresented: $store.showLogs) {
            LogView()
        }
        .onAppear {
            store.bootstrap()
            installPasteMonitor()
        }
    }

    /// 拦截 ⌘V：剪贴板是图片（无文本）时直接加为参考图；文本粘贴照常进输入框。
    private func installPasteMonitor() {
        guard !pasteMonitorInstalled else { return }
        pasteMonitorInstalled = true
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak store] event in
            guard let store,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers?.lowercased() == "v",
                  Self.pasteboardHasImageOnly()
            else { return event }
            store.pasteReferences()
            return nil
        }
    }

    private static func pasteboardHasImageOnly() -> Bool {
        let board = NSPasteboard.general
        if let urls = board.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            // Finder 复制的文件：全部是图片才拦截
            return urls.allSatisfy {
                UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true
            }
        }
        // 截图等位图数据：无文本才拦截，避免误杀富文本粘贴
        let hasText = (board.string(forType: .string)?.isEmpty == false)
        return !hasText && board.canReadObject(forClasses: [NSImage.self], options: nil)
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast = store.toast {
            Text(toast)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(.regularMaterial))
                .overlay(Capsule().strokeBorder(.quaternary))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { store.toast = nil }
        }
    }
}

// MARK: - 设置

struct SettingsView: View {
    @Bindable var store: StudioStore
    @Environment(\.dismiss) private var dismiss

    @State private var baseURLText = ""
    @State private var keyText = ""
    @State private var checking = false
    @State private var checkResult: String?
    @State private var language = Preferences.languageOverride ?? "system"

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Settings")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    applyRelayConfig()
                    store.savePreferences()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .hoverHighlight(cornerRadius: 12)
                .keyboardShortcut(.cancelAction)
            }

            section("gearshape", "General") {
                Picker("", selection: $language) {
                    Text("System").tag("system")
                    Text("中文").tag("zh-Hans")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: language) { _, newValue in
                    Preferences.languageOverride = newValue == "system" ? nil : newValue
                    store.showToast(String(localized: "Language changes take effect after relaunch"))
                }
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(shortPath(store.draft.outputDirectory))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    iconButton("folder.badge.gearshape", help: Text("Change…")) {
                        store.chooseOutputDirectory()
                    }
                    iconButton("arrow.up.right.square", help: Text("Open in Finder")) {
                        store.openOutputDirectory()
                    }
                }
            }

            section("cloud", "Third-party Relay") {
                TextField("Base URL", text: $baseURLText, prompt: Text(AppConstants.relayDefaultBaseURL.absoluteString))
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key", text: $keyText, prompt: Text("sk-…"))
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 8) {
                    Button(checking ? String(localized: "Checking…") : String(localized: "Save & Verify")) {
                        verifyRelay()
                    }
                    .controlSize(.small)
                    .disabled(checking || keyText.trimmingCharacters(in: .whitespaces).isEmpty)
                    if let result = checkResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.hasPrefix("✓") ? AnyShapeStyle(.green) : AnyShapeStyle(.orange))
                            .lineLimit(1)
                    }
                }
                if !store.relayModels.isEmpty {
                    Text("\(store.relayModels.count) models: \(store.relayModels.map(\.id).joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            section("terminal", "Codex") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(authReady ? .green : .orange)
                        .frame(width: 7, height: 7)
                    Text(authLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    iconButton("arrow.clockwise", help: Text("Re-check Login")) {
                        Task { await store.refreshAuth() }
                    }
                }
                TextField("Model override (empty = Codex config)", text: $store.draft.model)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { store.savePreferences() }
            }

            section("stethoscope", "Diagnostics") {
                HStack(spacing: 8) {
                    Text(shortPath(AppLog.logFileURL))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    iconButton("doc.text.magnifyingglass", help: Text("View Logs")) {
                        store.showLogs = true
                    }
                    iconButton("arrow.up.right.square", help: Text("Show in Finder")) {
                        AppLog.revealInFinder()
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Image("MascotHero")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
                    .opacity(0.9)
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 440, height: 600)
        .onAppear {
            baseURLText = store.relayBaseURL.absoluteString
            keyText = store.relayKey
        }
    }

    private func section(_ icon: String, _ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            content()
        }
    }

    private func iconButton(_ systemImage: String, help: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(5)
        }
        .buttonStyle(.plain)
        .hoverHighlight(cornerRadius: 6)
        .help(help)
    }

    private var authReady: Bool {
        if case .ready = store.auth { return true }
        return false
    }

    private var authLabel: String {
        switch store.auth {
        case .unknown: String(localized: "Checking…")
        case .ready: String(localized: "Signed in")
        case .missing: String(localized: "Not signed in (run codex login)")
        case .failed(let message): String(localized: "Failed: \(message)")
        }
    }

    private func shortPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func applyRelayConfig() {
        if let url = URL(string: baseURLText.trimmingCharacters(in: .whitespaces)), url.scheme != nil {
            store.relayBaseURL = url
        }
        store.relayKey = keyText.trimmingCharacters(in: .whitespaces)
    }

    private func verifyRelay() {
        applyRelayConfig()
        checking = true
        checkResult = nil
        Task {
            let error = await store.refreshRelayModels()
            checking = false
            checkResult = error.map { "✕ \($0)" }
                ?? "✓ " + String(localized: "Connected; model list updated")
        }
    }
}

// MARK: - 日志

struct LogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("Logs")
                    .font(.title3.weight(.semibold))
                Spacer()
                logButton("arrow.clockwise", help: Text("Refresh")) { text = AppLog.snapshot() }
                logButton("trash", help: Text("Clear")) {
                    AppLog.clear()
                    text = AppLog.snapshot()
                }
                logButton("doc.on.doc", help: Text("Copy")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }
            ScrollView {
                Text(text.isEmpty ? String(localized: "(empty)") : text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4)))
            HStack {
                Text(AppLog.logFileURL.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 720, height: 480)
        .onAppear { text = AppLog.snapshot() }
    }

    private func logButton(_ systemImage: String, help: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(5)
        }
        .buttonStyle(.plain)
        .hoverHighlight(cornerRadius: 6)
        .help(help)
    }
}
