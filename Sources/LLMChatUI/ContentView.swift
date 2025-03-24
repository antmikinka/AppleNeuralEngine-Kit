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
                }
                .padding()
            }
            
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
            .padding()
        }
    }
    
    private var modelLoadView: some View {
        VStack {
            Text("Select a model to begin")
                .font(.headline)
            
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
            
            if isLoading {
                VStack {
                    ProgressView()
                    Text(viewModel.loadingStatus)
                        .font(.caption)
                        .padding()
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}