import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: ChatViewModel
    var onOpenSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)
                .padding()
            
            Text("Welcome to ANE Chat Interface")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Run powerful language models directly on your device using Apple Neural Engine")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Divider()
                .padding(.vertical)
            
            VStack(alignment: .leading, spacing: 16) {
                welcomeStep(
                    number: "1",
                    title: "Load a Model",
                    description: "Open the settings panel to load a local model or download one from Hugging Face",
                    icon: "arrow.down.doc.fill"
                )
                
                welcomeStep(
                    number: "2",
                    title: "Create a Conversation",
                    description: "Use the conversations sidebar to create a new chat",
                    icon: "square.and.pencil"
                )
                
                welcomeStep(
                    number: "3",
                    title: "Start Chatting",
                    description: "Type a message and get AI-powered responses directly on your device",
                    icon: "text.bubble.fill"
                )
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            if !viewModel.isModelLoaded {
                Button("Open Settings") {
                    onOpenSettings()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .padding()
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func welcomeStep(number: String, title: String, description: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                
                Text(number)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}