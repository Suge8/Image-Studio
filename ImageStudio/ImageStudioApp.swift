import SwiftUI

@main
struct ImageStudioApp: App {
    @State private var store = StudioStore()

    var body: some Scene {
        Window("Image Studio", id: "main") {
            StudioView(store: store)
                .frame(minWidth: 900, minHeight: 560)
                .tint(.brand)
        }
        .defaultSize(width: 1100, height: 700)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(Text("Studio")) {
                Button("Generate") { store.submit() }
                    .keyboardShortcut(.return, modifiers: .command)
                Button("Stop") { store.cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Paste Reference Image") { store.pasteReferences() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Divider()
                Button("Open Output Folder") { store.openOutputDirectory() }
                Divider()
                Button("Logs…") { store.showLogs = true }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}
