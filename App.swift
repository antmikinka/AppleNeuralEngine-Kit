import SwiftUI

@main
struct AppleNeuralEngineKitApp: App {
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
            
            CommandMenu("Model") {
                Button("Load Model...") {
                    NotificationCenter.default.post(name: Notification.Name("LoadModel"), object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)
                
                Button("Convert Model...") {
                    NotificationCenter.default.post(name: Notification.Name("ConvertModel"), object: nil)
                }
                .keyboardShortcut("c", modifiers: .command)
            }
        }
    }
}