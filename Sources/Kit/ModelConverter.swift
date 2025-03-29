import Foundation

/// A class that handles conversion of models for Apple Neural Engine
@available(macOS 10.15, iOS 15.0, *)
public class ModelConverter: @unchecked Sendable {
    /// Error types that can occur during model conversion
    public enum ConversionError: Error, LocalizedError {
        case pythonNotFound
        case scriptNotFound(String)
        case conversionFailed(String)
        case invalidParameters
        
        public var errorDescription: String? {
            switch self {
            case .pythonNotFound:
                return "Python interpreter not found. Please check installation."
            case .scriptNotFound(let script):
                return "Conversion script \(script) not found. Please check installation."
            case .conversionFailed(let message):
                return "Conversion failed: \(message)"
            case .invalidParameters:
                return "Invalid conversion parameters. Please check inputs."
            }
        }
    }
    
    /// Parameters for model conversion
    public struct ConversionParameters {
        public let modelPath: String
        public let outputPath: String
        public let architecture: String?
        public let contextLength: Int
        public let batchSize: Int
        public let numChunks: Int?
        public let lutBits: Int?
        public let skipCheck: Bool
        public let verbose: Bool
        
        /// Initialize conversion parameters
        /// - Parameters:
        ///   - modelPath: Path to HuggingFace model directory
        ///   - outputPath: Path to save converted model
        ///   - architecture: Model architecture (auto-detected if nil)
        ///   - contextLength: Maximum context length
        ///   - batchSize: Batch size for prefill mode
        ///   - numChunks: Number of chunks to split the model into (auto-calculated if nil)
        ///   - lutBits: LUT quantization bits (nil for no quantization)
        ///   - skipCheck: Skip dependency checks
        ///   - verbose: Enable verbose output
        public init(modelPath: String, 
                   outputPath: String, 
                   architecture: String? = nil, 
                   contextLength: Int = 1024, 
                   batchSize: Int = 64, 
                   numChunks: Int? = nil, 
                   lutBits: Int? = nil, 
                   skipCheck: Bool = false, 
                   verbose: Bool = false) {
            self.modelPath = modelPath
            self.outputPath = outputPath
            self.architecture = architecture
            self.contextLength = contextLength
            self.batchSize = batchSize
            self.numChunks = numChunks
            self.lutBits = lutBits
            self.skipCheck = skipCheck
            self.verbose = verbose
        }
        
        /// Validate that parameters are valid
        public func validateParameters() -> Bool {
            guard !modelPath.isEmpty, !outputPath.isEmpty else { return false }
            guard contextLength > 0, batchSize > 0 else { return false }
            if let lutBits = lutBits, ![4, 6, 8].contains(lutBits) { return false }
            if let numChunks = numChunks, numChunks <= 0 { return false }
            return true
        }
    }
    
    /// Result of a model conversion
    public struct ConversionResult {
        public let success: Bool
        public let outputPath: String
        public let duration: TimeInterval
        public let stepsCompleted: [Int]
        public let artifacts: [String: Any]
        public let errorMessage: String?
        
        public init(success: Bool, 
                   outputPath: String, 
                   duration: TimeInterval, 
                   stepsCompleted: [Int] = [], 
                   artifacts: [String: Any] = [:], 
                   errorMessage: String? = nil) {
            self.success = success
            self.outputPath = outputPath
            self.duration = duration
            self.stepsCompleted = stepsCompleted
            self.artifacts = artifacts
            self.errorMessage = errorMessage
        }
    }
    
    /// Progress handler type for tracking conversion progress
    public typealias ProgressHandler = (Double, String) -> Void
    
    private var progressHandler: ProgressHandler?
    private var task: Process?
    
    /// Initialize a model converter
    public init() {}
    
    /// Set a handler to track conversion progress
    /// - Parameter handler: The progress handler
    public func setProgressHandler(_ handler: @escaping ProgressHandler) {
        self.progressHandler = handler
    }
    
    /// Convert a model to Apple Neural Engine format
    /// - Parameter params: Conversion parameters
    /// - Returns: Conversion result
    public func convertModel(_ params: ConversionParameters) async throws -> ConversionResult {
        // Validate parameters
        guard params.validateParameters() else {
            throw ConversionError.invalidParameters
        }
        
        // Find Python path
        let pythonPath = try findPythonInterpreter()
        
        // Find script path
        let scriptName = "convert_model.py"
        guard let scriptPath = findScriptInBundle(named: scriptName) else {
            throw ConversionError.scriptNotFound(scriptName)
        }
        
        // Create output directory if needed
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: params.outputPath),
            withIntermediateDirectories: true
        )
        
        // Build command arguments
        var arguments = [scriptPath,
                         "--model", params.modelPath,
                         "--output", params.outputPath,
                         "--context", String(params.contextLength),
                         "--batch-size", String(params.batchSize)]
        
        if let architecture = params.architecture {
            arguments.append(contentsOf: ["--architecture", architecture])
        }
        
        if let numChunks = params.numChunks {
            arguments.append(contentsOf: ["--chunks", String(numChunks)])
        }
        
        if let lutBits = params.lutBits {
            arguments.append(contentsOf: ["--lut", String(lutBits)])
        }
        
        if params.skipCheck {
            arguments.append("--skip-check")
        }
        
        if params.verbose {
            arguments.append("--verbose")
        }
        
        // Start conversion
        let startTime = Date()
        
        // Execute Python script and print command for debugging
        print("Executing conversion command:")
        print("\(pythonPath) \(scriptPath) \(arguments.joined(separator: " "))")
        
        let outputData = try await runPythonScriptAsync(
            pythonPath: pythonPath,
            scriptPath: scriptPath,
            arguments: arguments
        )
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Process output data and track progress
        if let output = String(data: outputData, encoding: .utf8) {
            // Parse progress information if available
            parseProgressFromOutput(output)
            
            // Check if conversion was successful
            if output.contains("Conversion completed successfully") {
                return ConversionResult(
                    success: true,
                    outputPath: params.outputPath,
                    duration: duration,
                    stepsCompleted: Array(1...12), // Assume all steps completed
                    artifacts: [:],
                    errorMessage: nil
                )
            } else {
                throw ConversionError.conversionFailed(output)
            }
        } else {
            throw ConversionError.conversionFailed("Could not decode output data")
        }
    }
    
    /// Cancel an ongoing conversion
    public func cancelConversion() {
        task?.terminate()
        task = nil
    }
    
    // MARK: - Private Methods
    
    private func findPythonInterpreter() throws -> String {
        // Try common paths
        let pythonPaths = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3"
        ]
        
        for path in pythonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // Try to find using which command
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["python3"]
        
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus == 0 {
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty,
               FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        throw ConversionError.pythonNotFound
    }
    
    private func findScriptInBundle(named scriptName: String) -> String? {
        // Try to find in bundle resources
        if let bundlePath = Bundle.main.path(forResource: scriptName, ofType: nil) {
            return bundlePath
        }
        
        // Try to find in scripts directory relative to executable
        let scriptDirectories = [
            "Scripts",
            "scripts",
            "../Scripts",
            "../scripts",
            "../../Scripts",
            "../../scripts",
            Bundle.main.bundlePath + "/Contents/Resources/Scripts",
            Bundle.main.bundlePath + "/Contents/Resources/scripts"
        ]
        
        // Get executable directory
        let executablePath = Bundle.main.executablePath ?? ""
        let executableDir = (executablePath as NSString).deletingLastPathComponent
        
        for directory in scriptDirectories {
            let basePaths = [
                directory,
                executableDir + "/" + directory,
                (executableDir as NSString).deletingLastPathComponent + "/" + directory
            ]
            
            for basePath in basePaths {
                let scriptPath = basePath + "/" + scriptName
                if FileManager.default.fileExists(atPath: scriptPath) {
                    return scriptPath
                }
            }
        }
        
        return nil
    }
    
    private func runPythonScriptAsync(pythonPath: String, scriptPath: String, arguments: [String]) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: pythonPath)
                task.arguments = arguments
                
                let outputPipe = Pipe()
                task.standardOutput = outputPipe
                
                let errorPipe = Pipe()
                task.standardError = errorPipe
                
                self.task = task
                
                try task.run()
                
                // Create output file handle to read asynchronously
                let outputHandle = outputPipe.fileHandleForReading
                let errorHandle = errorPipe.fileHandleForReading
                
                var outputData = Data()
                var errorData = Data()
                
                // Read output in chunks to parse progress
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        // Read in chunks to monitor progress
                        let chunkSize = 1024
                        var shouldContinue = true
                        
                        while shouldContinue {
                            if let chunk = try? outputHandle.read(upToCount: chunkSize), !chunk.isEmpty {
                                outputData.append(chunk)
                                
                                // Parse progress updates
                                if let chunkStr = String(data: chunk, encoding: .utf8) {
                                    self.parseProgressFromOutput(chunkStr)
                                }
                            } else {
                                shouldContinue = false
                            }
                            
                            // Check if task is still running
                            if !task.isRunning {
                                shouldContinue = false
                            }
                            
                            // Small delay to prevent excessive CPU usage
                            Thread.sleep(forTimeInterval: 0.1)
                        }
                        
                        // Read any remaining data
                        if let remainingData = try? outputHandle.readToEnd() {
                            outputData.append(remainingData)
                        }
                        
                        // Read error data
                        errorData = errorHandle.readDataToEndOfFile()
                        
                        // Wait for task to complete
                        task.waitUntilExit()
                        
                        if task.terminationStatus == 0 {
                            continuation.resume(returning: outputData)
                        } else {
                            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                            continuation.resume(throwing: ConversionError.conversionFailed(errorOutput))
                        }
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func parseProgressFromOutput(_ output: String) {
        // Example progress pattern: "Step X/Y: Description"
        let stepPattern = "Step (\\d+)/(\\d+): (.+)"
        
        if let regex = try? NSRegularExpression(pattern: stepPattern) {
            let nsRange = NSRange(output.startIndex..<output.endIndex, in: output)
            if let match = regex.firstMatch(in: output, range: nsRange) {
                if let currentStepRange = Range(match.range(at: 1), in: output),
                   let totalStepsRange = Range(match.range(at: 2), in: output),
                   let descriptionRange = Range(match.range(at: 3), in: output) {
                    
                    let currentStep = Int(output[currentStepRange]) ?? 0
                    let totalSteps = Int(output[totalStepsRange]) ?? 1
                    let stepDescription = String(output[descriptionRange])
                    
                    let progress = Double(currentStep) / Double(totalSteps)
                    
                    // Report progress via handler
                    DispatchQueue.main.async {
                        self.progressHandler?(progress, stepDescription)
                    }
                }
            }
        }
    }
}