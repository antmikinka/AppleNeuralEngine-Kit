import SwiftUI

struct SettingsSidebarView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var selectedTab = SettingsTab.models
    
    enum SettingsTab {
        case models
        case parameters
        case systemPrompt
        case history
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tabs
            HStack(spacing: 16) {
                ForEach([SettingsTab.models, SettingsTab.parameters, SettingsTab.systemPrompt, SettingsTab.history], id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
            .padding()
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .models:
                        modelSettings
                    case .parameters:
                        parameterSettings
                    case .systemPrompt:
                        systemPromptSettings
                    case .history:
                        historySettings
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .frame(minWidth: 300)
    }
    
    private func tabButton(for tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        
        return Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 4) {
                Image(systemName: iconName(for: tab))
                    .font(.system(size: 20))
                
                Text(tabTitle(for: tab))
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .accentColor : .primary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    private func iconName(for tab: SettingsTab) -> String {
        switch tab {
        case .models: return "cpu"
        case .parameters: return "slider.horizontal.3"
        case .systemPrompt: return "text.bubble"
        case .history: return "clock"
        }
    }
    
    private func tabTitle(for tab: SettingsTab) -> String {
        switch tab {
        case .models: return "Models"
        case .parameters: return "Parameters"
        case .systemPrompt: return "Prompt"
        case .history: return "History"
        }
    }
    
    // MARK: - Tab Contents
    
    @State private var isShowingDirectoryPicker = false
    
    private var modelSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Model Settings")
                .font(.headline)
            
            // Step 1: Select model directory
            Group {
                Text("Step 1: Select Model Directory")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Button("Select Directory...") {
                    isShowingDirectoryPicker = true
                }
                .buttonStyle(.bordered)
                .fileImporter(
                    isPresented: $isShowingDirectoryPicker,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            viewModel.localModelDirectory = url
                        }
                    case .failure(let error):
                        print("Error selecting directory: \(error.localizedDescription)")
                    }
                }
                
                // Display selected directory
                if let directory = viewModel.localModelDirectory {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected Directory:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(directory.lastPathComponent)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Step 2: Load model
            Group {
                Text("Step 2: Initialize Model")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                // Model loading button
                Button("Load Selected Model") {
                    Task {
                        await viewModel.loadLocalModel()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isModelLoading || viewModel.localModelDirectory == nil)
                
                Button("Download from Hugging Face") {
                    Task {
                        await viewModel.loadRemoteModel()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isModelLoading)
            }
            
            // Loading progress
            if viewModel.isModelLoading {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.loadProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .animation(.easeInOut, value: viewModel.loadProgress)
                    
                    Text(viewModel.loadingStatus)
                        .font(.caption)
                }
            }
            
            Spacer()
        }
    }
    
    private var parameterSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generation Parameters")
                .font(.headline)
            
            // Temperature
            VStack(alignment: .leading) {
                HStack {
                    Text("Temperature:")
                    Spacer()
                    Text("\(viewModel.temperature, specifier: "%.2f")")
                }
                
                Slider(value: $viewModel.temperature, in: 0...2, step: 0.05)
                
                Text("Controls randomness. Lower values are more deterministic, higher values are more creative.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Top-P
            VStack(alignment: .leading) {
                HStack {
                    Text("Top-P:")
                    Spacer()
                    Text("\(viewModel.topP, specifier: "%.2f")")
                }
                
                Slider(value: $viewModel.topP, in: 0...1, step: 0.05)
                
                Text("Nucleus sampling. Controls diversity by considering only the top percentage of probability mass.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Max Tokens
            VStack(alignment: .leading) {
                HStack {
                    Text("Max Tokens:")
                    Spacer()
                    Text("\(viewModel.maxNewTokens)")
                }
                
                Slider(value: Binding<Double>(
                    get: { Double(viewModel.maxNewTokens) },
                    set: { viewModel.maxNewTokens = Int($0) }
                ), in: 10...500, step: 10)
                
                Text("Maximum number of tokens to generate in the response.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var systemPromptSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("System Prompt")
                .font(.headline)
            
            if let conversation = viewModel.conversationStore.selectedConversation {
                TextEditor(text: Binding<String>(
                    get: { conversation.systemPrompt },
                    set: { viewModel.conversationStore.updateSystemPrompt($0) }
                ))
                .font(.body)
                .padding(8)
                .frame(height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                
                Text("System prompt provides context and instructions for the model's responses.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // Preset system prompts
                Text("Presets:")
                    .font(.subheadline)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        systemPromptButton("General Assistant", prompt: "You are a helpful, respectful assistant. Always provide accurate and useful information.")
                        
                        systemPromptButton("Code Helper", prompt: "You are a coding assistant specialized in helping with programming tasks. Provide clear and effective code snippets and explanations.")
                        
                        systemPromptButton("Creative Writer", prompt: "You are a creative writing assistant. Help users craft engaging stories, poems, and other creative content.")
                    }
                }
            } else {
                Text("No conversation selected")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func systemPromptButton(_ title: String, prompt: String) -> some View {
        Button(action: {
            viewModel.conversationStore.updateSystemPrompt(prompt)
        }) {
            Text(title)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var historySettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("History & Export")
                .font(.headline)
            
            // Current conversation info
            if let conversation = viewModel.conversationStore.selectedConversation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Conversation:")
                        .font(.subheadline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text(conversation.title)
                                .font(.body)
                            
                            Text("Created: \(formatDate(conversation.createdAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Messages: \(conversation.messages.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                }
                
                Divider()
                
                // Export options
                Button("Clear Current Conversation") {
                    if let id = viewModel.conversationStore.selectedConversationId {
                        viewModel.conversationStore.deleteConversation(id)
                        viewModel.conversationStore.createNewConversation()
                        viewModel.loadSelectedConversation()
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
            } else {
                Text("No conversation selected")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}