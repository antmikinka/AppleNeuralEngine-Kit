import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var repoID: String = ""
    @State private var maxTokens: String = "60"
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDirectory: URL?
    @State private var isShowingFilePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Local Model")) {
                    Button("Select Model Directory") {
                        isShowingFilePicker = true
                    }
                    
                    if let directory = viewModel.localModelDirectory {
                        Text(directory.lastPathComponent)
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
                    TextField("Cache Processor Model Name", text: $viewModel.cacheProcessorModelName)
                    TextField("Logit Processor Model Name", text: $viewModel.logitProcessorModelName)
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
            .fileImporter(
                isPresented: $isShowingFilePicker,
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