import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var showWelcome = true
    @State private var navigationState = NavigationState()
    
    struct NavigationState {
        var columnVisibility: NavigationSplitViewVisibility = .automatic
        var showSettings: Bool = false
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $navigationState.columnVisibility) {
            // First column: Conversations sidebar
            ConversationListView(viewModel: viewModel)
                .frame(minWidth: 250, idealWidth: 300, maxWidth: 350)
        } content: {
            // Second column: Chat or welcome view
            VStack {
                if viewModel.isModelLoaded {
                    if !showWelcome {
                        chatView
                    } else {
                        WelcomeView(viewModel: viewModel, onOpenSettings: {
                            navigationState.showSettings = true
                        })
                        .onAppear {
                            // Auto-hide welcome after first load
                            if viewModel.conversationStore.conversations.first?.messages.count ?? 0 > 0 {
                                showWelcome = false
                            }
                        }
                    }
                } else {
                    WelcomeView(viewModel: viewModel, onOpenSettings: {
                        navigationState.showSettings = true
                    })
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        navigationState.showSettings.toggle()
                    }) {
                        Image(systemName: "gear")
                    }
                }
                
                if viewModel.isModelLoaded && showWelcome {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Start Chatting") {
                            showWelcome = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        } detail: {
            // Third column: Settings sidebar (only shown when requested)
            if navigationState.showSettings {
                SettingsSidebarView(viewModel: viewModel)
                    .frame(minWidth: 350, idealWidth: 400, maxWidth: 450)
            } else {
                Color.clear // Empty detail view when settings aren't shown
            }
        }
        .onAppear {
            // Initialize the conversations when the app starts
            viewModel.loadSelectedConversation()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    var navigationTitle: String {
        if viewModel.isModelLoaded {
            if showWelcome {
                return "Welcome"
            } else if let conversation = viewModel.conversationStore.selectedConversation {
                return conversation.title
            } else {
                return "New Chat"
            }
        } else {
            return "ANE Chat"
        }
    }
    
    private var chatView: some View {
        VStack {
            // Chat messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        ChatBubbleView(message: message)
                    }
                    
                    if viewModel.isGenerating {
                        HStack {
                            ProgressView()
                                .padding(.horizontal)
                            Text("Generating...")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                    }
                    
                    // Show performance metrics after generation completes
                    if let stats = viewModel.generationStats, !viewModel.isGenerating {
                        performanceStats(stats)
                    }
                }
                .padding()
            }
            
            // Model info and input area
            VStack(spacing: 4) {
                // Model information banner
                if let directory = viewModel.localModelDirectory {
                    modelInfoBanner(directory)
                }
                
                // Text input
                HStack {
                    TextField("Type a message...", text: $inputText)
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .disabled(viewModel.isGenerating)
                        .textFieldStyle(PlainTextFieldStyle())
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                        .autocorrectionDisabled()
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                    }
                    .disabled(inputText.isEmpty || viewModel.isGenerating)
                }
            }
            .padding()
        }
    }
    
    private func performanceStats(_ stats: GenerationStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Generation Stats:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Label("\(stats.tokenCount) tokens", systemImage: "number")
                Spacer()
                Label(String(format: "%.2f s", stats.totalTimeSeconds), systemImage: "clock")
            }
            .font(.caption)
            
            HStack {
                Label(stats.formattedLatency, systemImage: "speedometer")
                Spacer()
                Label(stats.formattedThroughput, systemImage: "gauge")
            }
            .font(.caption)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func modelInfoBanner(_ directory: URL) -> some View {
        HStack {
            Label {
                Text(directory.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                Image(systemName: "cpu")
                    .font(.caption)
            }
            
            Spacer()
            
            if viewModel.loadTime > 0 {
                Text("Loaded: \(String(format: "%.2f", viewModel.loadTime))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func sendMessage() {
        Task {
            if !inputText.isEmpty {
                let text = inputText
                inputText = ""
                showWelcome = false
                await viewModel.sendMessage(text)
            }
        }
    }
}

#Preview {
    ContentView()
}