import SwiftUI

@main
struct ANEChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About AppleNeuralEngine-Kit") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                            string: "A toolkit for running CoreML LLMs on Apple's Neural Engine",
                            attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 11)]
                        )]
                    )
                }
            }
            
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    NotificationCenter.default.post(name: Notification.Name("NewChat"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}