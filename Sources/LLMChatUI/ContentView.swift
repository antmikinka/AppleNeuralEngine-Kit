import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isModelLoaded {
                    chatView
                } else {
                    modelLoadView
                }
            }
            .navigationTitle("LLM Chat")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showSettings.toggle()
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    private var chatView: some View {
        VStack {
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
                }
                .padding()
            }
            
            // Input area
            VStack(spacing: 4) {
                // Model information banner
                if let directory = viewModel.localModelDirectory {
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
                
                // Text input
                HStack {
                    TextField("Type a message...", text: $inputText)
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .disabled(viewModel.isGenerating)
                    
                    Button(action: {
                        Task {
                            if !inputText.isEmpty {
                                let text = inputText
                                inputText = ""
                                await viewModel.sendMessage(text)
                            }
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                    }
                    .disabled(inputText.isEmpty || viewModel.isGenerating)
                }
            }
            .padding()
        }
    }
    
    private var modelLoadView: some View {
        VStack {
            Text("Select a model to begin")
                .font(.headline)
            
            if viewModel.isModelLoading {
                // Loading progress view
                VStack(spacing: 16) {
                    ProgressView(value: viewModel.loadProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(maxWidth: 300)
                        .animation(.easeInOut, value: viewModel.loadProgress)
                    
                    Text(viewModel.loadingStatus)
                        .font(.caption)
                    
                    if viewModel.loadTime > 0 {
                        Text("Load time: \(String(format: "%.2f", viewModel.loadTime)) seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding()
            } else {
                // Model selection buttons
                Button("Load Local Model") {
                    Task {
                        await viewModel.loadLocalModel()
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                Button("Download from Hugging Face") {
                    showSettings.toggle()
                }
                .buttonStyle(.bordered)
                .padding(.bottom)
            }
            
            // Show directory info if available
            if let directory = viewModel.localModelDirectory {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model Directory:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(directory.lastPathComponent)
                        .font(.caption)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}