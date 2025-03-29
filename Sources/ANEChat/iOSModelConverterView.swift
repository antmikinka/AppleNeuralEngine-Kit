import SwiftUI
import ANEKit

/// iOS-specific model conversion view
struct iOSModelConverterView: View {
    @State private var modelDirectory: URL?
    @State private var outputDirectory: URL?
    @State private var selectedArchitecture: String? = nil
    @State private var contextLength: Double = 1024
    @State private var batchSize: Double = 64
    @State private var numChunks: Double? = nil
    @State private var selectedQuantOption: Int = 0
    
    @State private var isConverting: Bool = false
    @State private var progress: Double = 0.0
    @State private var currentStep: String = ""
    @State private var conversionResult: ConversionResult? = nil
    @State private var errorMessage: String? = nil
    @State private var showDirectoryPicker = false
    @State private var isSelectingModelDir = false
    
    private let converter = ModelConverter()
    
    struct ConversionResult {
        let success: Bool
        let outputPath: String
        let duration: TimeInterval
        let errorMessage: String?
    }
    
    // Architecture options for picker
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
    
    // Quantization options for picker
    private let quantOptions = [
        "None",
        "4-bit",
        "6-bit",
        "8-bit"
    ]
    
    var body: some View {
        NavigationStack {
            List {
                // Model selection section
                Section(header: Text("Model Selection")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Model Directory")
                            Spacer()
                            Button(action: {
                                isSelectingModelDir = true
                                showDirectoryPicker = true
                            }) {
                                Text(modelDirectory?.lastPathComponent ?? "Select Directory")
                                    .foregroundColor(modelDirectory == nil ? .blue : .primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        HStack {
                            Text("Output Directory")
                            Spacer()
                            Button(action: {
                                isSelectingModelDir = false
                                showDirectoryPicker = true
                            }) {
                                Text(outputDirectory?.lastPathComponent ?? "Select Directory")
                                    .foregroundColor(outputDirectory == nil ? .blue : .primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Configuration section
                Section(header: Text("Model Configuration")) {
                    // Architecture selection
                    Picker("Architecture", selection: $selectedArchitecture) {
                        Text("Auto-detect").tag(nil as String?)
                        ForEach(architectureOptions.dropFirst(), id: \.self) { architecture in
                            Text(architecture).tag(architecture as String?)
                        }
                    }
                    
                    // Context length
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Context Length")
                            Spacer()
                            Text("\(Int(contextLength))")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $contextLength, in: 512...4096, step: 512)
                    }
                    
                    // Batch size
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Batch Size")
                            Spacer()
                            Text("\(Int(batchSize))")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $batchSize, in: 1...256, step: 1)
                    }
                    
                    // Chunks
                    VStack(alignment: .leading) {
                        Toggle("Auto Chunks", isOn: Binding(
                            get: { numChunks == nil },
                            set: { if $0 { numChunks = nil } else { numChunks = 4 } }
                        ))
                        
                        if numChunks != nil {
                            HStack {
                                Text("Number of Chunks")
                                Spacer()
                                Text("\(Int(numChunks ?? 4))")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: Binding(
                                get: { numChunks ?? 4 },
                                set: { numChunks = $0 }
                            ), in: 1...16, step: 1)
                        }
                    }
                    
                    // Quantization
                    Picker("Quantization", selection: $selectedQuantOption) {
                        ForEach(0..<quantOptions.count, id: \.self) { index in
                            Text(quantOptions[index]).tag(index)
                        }
                    }
                }
                
                // Progress section
                if isConverting {
                    Section(header: Text("Conversion Progress")) {
                        VStack(spacing: 12) {
                            ProgressView(value: progress)
                            Text(currentStep)
                                .font(.caption)
                        }
                    }
                }
                
                // Error section
                if let errorMessage = errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Error Occurred")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.caption)
                        }
                    }
                }
                
                // Result section
                if let result = conversionResult, result.success {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Conversion Successful!")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("Duration: \(String(format: "%.1f", result.duration)) seconds")
                            Text("Output: \(result.outputPath)")
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }
                }
                
                // Action section
                Section {
                    if isConverting {
                        Button("Cancel Conversion", role: .destructive) {
                            cancelConversion()
                        }
                    } else {
                        Button(action: startConversion) {
                            Text("Convert Model")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .disabled(modelDirectory == nil || outputDirectory == nil)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Model Conversion")
            .sheet(isPresented: $showDirectoryPicker) {
                // On iOS we would use a document picker here
                VStack {
                    Text("Select \(isSelectingModelDir ? "Model" : "Output") Directory")
                        .font(.headline)
                        .padding()
                    
                    Text("On iOS, this would use UIDocumentPickerViewController")
                        .padding()
                    
                    Button("Dismiss") {
                        showDirectoryPicker = false
                        
                        // Simulate selection for demo purposes
                        if isSelectingModelDir {
                            modelDirectory = URL(string: "file:///models/Llama-3")
                        } else {
                            outputDirectory = URL(string: "file:///converted_models")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
        }
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
    
    private func startConversion() {
        guard let modelDir = modelDirectory, let outputDir = outputDirectory else {
            errorMessage = "Please select both model and output directories"
            return
        }
        
        errorMessage = nil
        conversionResult = nil
        isConverting = true
        progress = 0.0
        currentStep = "Preparing for conversion..."
        
        // Convert selectedQuantOption to actual lutBits value
        let lutBits: Int? = selectedQuantOption == 0 ? nil : (selectedQuantOption == 1 ? 4 : (selectedQuantOption == 2 ? 6 : 8))
        
        // In a real implementation, we would call model conversion here
        // For now, just simulate the process
        
        // Simulate a conversion process
        let totalDuration: TimeInterval = 10.0
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            DispatchQueue.main.async {
                let newProgress = min(1.0, self.progress + 0.1)
                self.progress = newProgress
                
                let stepIndex = Int(newProgress * 10)
                self.currentStep = "Step \(stepIndex + 1) of 10: \(self.generateRandomStep(stepIndex))"
                
                if newProgress >= 1.0 {
                    timer.invalidate()
                    self.isConverting = false
                    self.conversionResult = ConversionResult(
                        success: true,
                        outputPath: outputDir.path,
                        duration: totalDuration,
                        errorMessage: nil
                    )
                }
            }
        }
        timer.fire()
    }
    
    private func cancelConversion() {
        isConverting = false
        progress = 0.0
        currentStep = "Conversion cancelled"
    }
    
    private func generateRandomStep(_ index: Int) -> String {
        let steps = [
            "Analyzing model architecture",
            "Extracting model parameters",
            "Converting embeddings layer",
            "Processing transformer blocks",
            "Optimizing attention mechanism",
            "Creating KV cache processor",
            "Building logit processor",
            "Applying quantization",
            "Combining model chunks",
            "Finalizing conversion"
        ]
        
        return index < steps.count ? steps[index] : "Processing..."
    }
}

#Preview {
    iOSModelConverterView()
}