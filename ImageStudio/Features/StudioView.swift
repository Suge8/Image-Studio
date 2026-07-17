import SwiftUI

struct StudioView: View {
    @Bindable var store: StudioStore

    var body: some View {
        HStack(spacing: 0) {
            ComposerView(store: store)
                .frame(width: 340)
            GalleryView(store: store)
                .background(Color.canvas)
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) { toastView }
        .animation(.spring(duration: 0.3), value: store.toast)
        .sheet(isPresented: $store.showSettings) {
            SettingsView(store: store)
        }
        .sheet(isPresented: $store.showLogs) {
            LogView()
        }
        .onAppear { store.bootstrap() }
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
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.title2.weight(.semibold))
                .padding(20)

            Form {
                generalSection
                relaySection
                codexSection
                diagnosticsSection
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Done") {
                    applyRelayConfig()
                    store.savePreferences()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(20)
        }
        .frame(width: 500, height: 620)
        .onAppear {
            baseURLText = store.relayBaseURL.absoluteString
            keyText = store.relayKey
        }
    }

    private var generalSection: some View {
        Section("General") {
            Picker("Language", selection: $language) {
                Text("System").tag("system")
                Text("中文").tag("zh-Hans")
                Text("English").tag("en")
            }
            .onChange(of: language) { _, newValue in
                Preferences.languageOverride = newValue == "system" ? nil : newValue
                store.showToast(String(localized: "Language changes take effect after relaunch"))
            }
            LabeledContent("Output Folder") {
                HStack(spacing: 8) {
                    Text(shortPath(store.draft.outputDirectory))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Change…") { store.chooseOutputDirectory() }
                    Button {
                        store.openOutputDirectory()
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .help(Text("Open in Finder"))
                }
            }
        }
    }

    private var relaySection: some View {
        Section("Third-party Relay") {
            TextField("Base URL", text: $baseURLText, prompt: Text(AppConstants.relayDefaultBaseURL.absoluteString))
            SecureField("API Key", text: $keyText, prompt: Text("sk-…"))
            HStack {
                Button(checking ? String(localized: "Checking…") : String(localized: "Save & Verify")) {
                    verifyRelay()
                }
                .disabled(checking || keyText.trimmingCharacters(in: .whitespaces).isEmpty)
                if let result = checkResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.hasPrefix("✓") ? AnyShapeStyle(.green) : AnyShapeStyle(.orange))
                }
            }
            if !store.relayModels.isEmpty {
                Text("\(store.relayModels.count) models: \(store.relayModels.map(\.id).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var codexSection: some View {
        Section("Codex") {
            LabeledContent("Login", value: authLabel)
            Button("Re-check Login") {
                Task { await store.refreshAuth() }
            }
            TextField("Model override (empty = Codex config)", text: $store.draft.model)
                .onSubmit { store.savePreferences() }
            Text("This is the Responses host model (e.g. gpt-5.6-sol), not the underlying gpt-image name.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            HStack {
                Button("View Logs") { store.showLogs = true }
                Button("Show in Finder") { AppLog.revealInFinder() }
            }
            Text(AppLog.logFileURL.path)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
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
            HStack {
                Text("Logs")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Refresh") { text = AppLog.snapshot() }
                Button("Clear") {
                    AppLog.clear()
                    text = AppLog.snapshot()
                }
                Button("Copy") {
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
}
