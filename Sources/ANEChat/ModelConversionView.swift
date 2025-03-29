import SwiftUI
import Foundation
import ANEKit

struct ModelConversionView: View {
    @State private var modelPath: String = ""
    @State private var outputPath: String = ""
    @State private var selectedArchitecture: String? = nil
    @State private var contextLength: Int = 1024
    @State private var batchSize: Int = 64
    @State private var numChunks: Int? = nil
    @State private var selectedLutOption: Int = 0 // 0=None, 1=4-bit, 2=6-bit, 3=8-bit
    
    @State private var isConverting: Bool = false
    @State private var progress: Double = 0.0
    @State private var currentStep: String = ""
    @State private var conversionResult: ConversionResult? = nil
    @State private var errorMessage: String? = nil
    
    private let converter = ModelConverter()
    
    // Architecture options for dropdown
    private let architectureOptions = [
        "Auto-detect",
        "qwen",
        "qwq",
        "llama",
        "mistral",
        "phi",
        "gemma",
        "falcon"
    ]
    
    // LUT options for dropdown
    private let lutOptions = [
        "None",
        "4-bit",
        "6-bit",
        "8-bit"
    ]
    
    struct ConversionResult {
        let success: Bool
        let outputPath: String
        let duration: TimeInterval
        let errorMessage: String?
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Model Conversion")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top])
            
            Text("Convert models to Apple Neural Engine format")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 20)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Model path section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model Path")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Select the HuggingFace model directory")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            TextField("Path to HuggingFace model", text: $modelPath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(maxWidth: .infinity)
                            
                            Button("Browse") {
                                selectModelPath()
                            }
                            .buttonStyle(.bordered)
                            .frame(width: 100)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Output path section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Output Path")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Select where to save the converted model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            TextField("Path for converted model", text: $outputPath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(maxWidth: .infinity)
                            
                            Button("Browse") {
                                selectOutputPath()
                            }
                            .buttonStyle(.bordered)
                            .frame(width: 100)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Model options section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Conversion Options")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.bottom, 4)
                        
                        // Architecture selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Architecture")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $selectedArchitecture) {
                                Text("Auto-detect").tag(nil as String?)
                                ForEach(architectureOptions.dropFirst(), id: \.self) { architecture in
                                    Text(architecture).tag(architecture as String?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        
                        // Parameters grid
                        HStack(spacing: 20) {
                            // Context length
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Context Length")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextField("", value: $contextLength, formatter: NumberFormatter())
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Batch size
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Batch Size")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextField("", value: $batchSize, formatter: NumberFormatter())
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        HStack(spacing: 20) {
                            // Chunks
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Chunks")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextField("Auto", value: $numChunks, formatter: NumberFormatter())
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .placeholder("Auto", when: numChunks == nil)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // LUT Bits
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Quantization")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $selectedLutOption) {
                                    ForEach(0..<lutOptions.count, id: \.self) { index in
                                        Text(lutOptions[index]).tag(index)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Progress section
                    if isConverting {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Converting Model...")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(maxWidth: .infinity)
                            
                            Text(currentStep)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Error message display
                    if let errorMessage = errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Error")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.callout)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Result summary display
                    if let result = conversionResult, result.success {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Conversion Successful!")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            Text("Duration: \(String(format: "%.1f", result.duration)) seconds")
                                .font(.callout)
                            
                            Text("Output: \(result.outputPath)")
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        if isConverting {
                            Button("Cancel") {
                                cancelConversion()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                        } else {
                            Button("Convert Model") {
                                startConversion()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(modelPath.isEmpty || outputPath.isEmpty)
                            .frame(maxWidth: .infinity)
                        }
                        
                        if let result = conversionResult, result.success {
                            Button("Open Output Folder") {
                                NSWorkspace.shared.open(URL(fileURLWithPath: result.outputPath))
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 20)
            }
            .background(Color(.windowBackgroundColor))
        }
        .frame(minWidth: 600, idealWidth: 800, minHeight: 600, idealHeight: 700)
        .onAppear {
            setupModelConverter()
        }
    }
    
    private func setupModelConverter() {
        converter.setProgressHandler { progress, step in
            DispatchQueue.main.async {
                self.progress = progress
                self.currentStep = step
            }
        }
    }
    
    private func selectModelPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Select HuggingFace Model Directory"
        panel.message = "Choose the directory containing the HuggingFace model files"
        
        if panel.runModal() == .OK, let url = panel.url {
            modelPath = url.path
        }
    }
    
    private func selectOutputPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Select Output Directory"
        panel.message = "Choose where to save the converted model"
        
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }
    
    private func startConversion() {
        errorMessage = nil
        conversionResult = nil
        isConverting = true
        progress = 0.0
        currentStep = "Preparing for conversion..."
        
        // Convert selectedLutOption to actual lutBits value
        let lutBits: Int? = selectedLutOption == 0 ? nil : (selectedLutOption == 1 ? 4 : (selectedLutOption == 2 ? 6 : 8))
        
        // Create conversion parameters
        let params = ModelConverter.ConversionParameters(
            modelPath: self.modelPath,
            outputPath: self.outputPath,
            architecture: self.selectedArchitecture,
            contextLength: self.contextLength,
            batchSize: self.batchSize,
            numChunks: self.numChunks,
            lutBits: lutBits,
            verbose: true
        )
        
        // Start actual conversion
        Task {
            do {
                let startTime = Date()
                let result = try await converter.convertModel(params)
                let duration = Date().timeIntervalSince(startTime)
                
                DispatchQueue.main.async {
                    self.isConverting = false
                    self.progress = 1.0
                    self.conversionResult = ConversionResult(
                        success: true,
                        outputPath: self.outputPath,
                        duration: duration,
                        errorMessage: nil
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    self.isConverting = false
                    self.progress = 0.0
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func cancelConversion() {
        // Cancel the ongoing conversion
        converter.cancelConversion()
        isConverting = false
        progress = 0.0
        currentStep = "Conversion cancelled"
        errorMessage = "Conversion was cancelled by user"
    }
}

// Helper function to generate random step descriptions for simulation
func generateRandomStepDescription(_ step: Int) -> String {
    let steps = [
        "Analyzing model architecture",
        "Extracting model parameters",
        "Converting embeddings layer",
        "Processing transformer blocks",
        "Optimizing attention mechanism",
        "Creating KV cache processor",
        "Building logit processor",
        "Applying LUT quantization",
        "Combining model chunks",
        "Finalizing conversion"
    ]
    
    return steps[step - 1]
}

// Extension to support placeholder text in TextField
extension View {
    func placeholder<Content: View>(
        _ placeholderText: String,
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            content().opacity(shouldShow ? 1 : 0)
            self
        }
    }
    
    func placeholder(_ text: String, when shouldShow: Bool) -> some View {
        placeholder(text, when: shouldShow) {
            Text(text).foregroundColor(.gray)
                .padding(.horizontal, 4)
        }
    }
}

#Preview {
    ModelConversionView()
}