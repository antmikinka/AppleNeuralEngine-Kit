import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var repoID: String = ""
    @State private var maxTokens: String = "60"
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Local Model")) {                    
                    if let directory = viewModel.localModelDirectory {
                        Text("Current Directory: \(directory.lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No directory selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    TextField("Model Prefix (optional)", text: Binding(
                        get: { viewModel.localModelPrefix ?? "" },
                        set: { viewModel.localModelPrefix = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section(header: Text("Hugging Face Model")) {
                    TextField("Repository ID (e.g. smpanaro/Llama-2-7b-coreml)", text: $repoID)
                    
                    Button("Download Model") {
                        Task {
                            viewModel.repoID = repoID
                            await viewModel.loadRemoteModel()
                            dismiss()
                        }
                    }
                    .disabled(repoID.isEmpty)
                }
                
                Section(header: Text("Generation Settings")) {
                    TextField("Max New Tokens", text: $maxTokens)
                        .onChange(of: maxTokens) { oldValue, newValue in
                            if let intValue = Int(newValue) {
                                viewModel.maxNewTokens = intValue
                            }
                        }
                    
                    TextField("Tokenizer Name (optional)", text: Binding(
                        get: { viewModel.tokenizerName ?? "" },
                        set: { viewModel.tokenizerName = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section(header: Text("Advanced Settings")) {
                    // Add temperature and top-p controls
                    HStack {
                        Text("Temperature:")
                        Spacer()
                        Text(String(format: "%.2f", viewModel.temperature))
                    }
                    Slider(value: $viewModel.temperature, in: 0...2, step: 0.05)
                    
                    HStack {
                        Text("Top-P:")
                        Spacer()
                        Text(String(format: "%.2f", viewModel.topP))
                    }
                    Slider(value: $viewModel.topP, in: 0...1, step: 0.05)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Initialize from viewModel values
            self.repoID = viewModel.repoID ?? ""
            self.maxTokens = String(viewModel.maxNewTokens)
        }
    }
}

#Preview {
    SettingsView(viewModel: ChatViewModel())
}