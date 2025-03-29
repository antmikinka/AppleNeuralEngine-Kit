import Foundation
import Tokenizers
import Hub
import CoreML
import SwiftUI
import ANEKit

class ChatViewModel: ObservableObject {
    // Model state
    @Published var isModelLoaded = false
    @Published var isModelLoading = false
    @Published var isGenerating = false
    @Published var messages: [ChatMessage] = []
    @Published var loadingStatus = "Loading model..."
    @Published var loadProgress: Double = 0.0
    @Published var showError = false
    @Published var errorMessage = ""
    
    // Performance metrics
    @Published var loadTime: Double = 0
    @Published var generationStats: GenerationStats?
    
    // Conversations
    @Published var conversationStore = ConversationStore()
    
    // Model configuration
    var repoID: String?
    var localModelDirectory: URL?
    var localModelPrefix: String?
    var tokenizerName: String?
    var maxNewTokens = 60
    
    // Generation parameters
    var temperature: Double = 0.7
    var topP: Double = 0.9
    
    // Core components
    private var pipeline: ModelPipeline?
    private var tokenizer: Tokenizer?
    private var generator: TextGenerator?
    
    // Load a model from a local directory
    func loadLocalModel() async {
        await MainActor.run {
            isModelLoaded = false
            isModelLoading = true
            loadProgress = 0.0
            loadingStatus = "Preparing to load model..."
        }
        
        do {
            guard let modelDirectory = localModelDirectory else {
                await showErrorMessage("No model directory specified")
                await MainActor.run { isModelLoading = false }
                return
            }
            
            await MainActor.run {
                loadingStatus = "Inferring tokenizer..."
            }
            
            guard let tokenizerName = tokenizerName ?? inferTokenizer() else {
                await showErrorMessage("Unable to infer tokenizer. Please configure tokenizer.")
                await MainActor.run { isModelLoading = false }
                return
            }
            
            await MainActor.run {
                loadingStatus = "Detecting model components..."
                loadProgress = 0.05
            }
            
            // Auto-detect processor files
            let fileManager = FileManager.default
            let directoryContents = try fileManager.contentsOfDirectory(
                at: modelDirectory, 
                includingPropertiesForKeys: [.isDirectoryKey], 
                options: [.skipsHiddenFiles]
            )
            
            // Find cache processor file
            let cacheProcessorFiles = directoryContents.filter { 
                $0.lastPathComponent.lowercased().contains("cache") && 
                $0.lastPathComponent.hasSuffix(".mlmodelc")
            }
            let cacheProcessorModelName = cacheProcessorFiles.first?.lastPathComponent ?? "cache-processor.mlmodelc"
            
            // Find logit processor file
            let logitProcessorFiles = directoryContents.filter { 
                $0.lastPathComponent.lowercased().contains("logit") && 
                $0.lastPathComponent.hasSuffix(".mlmodelc")
            }
            let logitProcessorModelName = logitProcessorFiles.first?.lastPathComponent ?? "logit-processor.mlmodelc"
            
            await MainActor.run {
                loadingStatus = "Creating model pipeline..."
                loadProgress = 0.1
            }
            
            let pipeline = try ModelPipeline.from(
                folder: modelDirectory,
                modelPrefix: localModelPrefix,
                cacheProcessorModelName: cacheProcessorModelName,
                logitProcessorModelName: logitProcessorModelName
            )
            
            // Load pipeline with progress updates
            let loadDuration = try await pipeline.loadWithProgress { status, progress in
                Task { @MainActor in
                    self.loadingStatus = status
                    self.loadProgress = progress
                }
            }
            
            await MainActor.run {
                loadingStatus = "Loading tokenizer..."
                loadProgress = 0.9
            }
            
            let tokenizer = try await AutoTokenizer.from(pretrained: tokenizerName, hubApi: .init())
            
            // Initialize text generator
            let generator = TextGenerator(pipeline: pipeline, tokenizer: tokenizer)
            
            // Store references
            self.pipeline = pipeline
            self.tokenizer = tokenizer
            self.generator = generator
            self.loadTime = loadDuration.converted(to: .seconds).value
            
            await MainActor.run {
                self.loadingStatus = "Model loaded in \(String(format: "%.2f", loadDuration.converted(to: .seconds).value)) seconds"
                self.loadProgress = 1.0
                self.isModelLoaded = true
                self.isModelLoading = false
            }
            
        } catch {
            await showErrorMessage("Failed to load model: \(error.localizedDescription)")
            await MainActor.run { isModelLoading = false }
        }
    }
    
    // Load a model from Hugging Face
    func loadRemoteModel() async {
        await MainActor.run {
            isModelLoaded = false
            isModelLoading = true
            loadProgress = 0.0
            loadingStatus = "Checking Hugging Face repo..."
        }
        
        do {
            guard let repoID = repoID else {
                await showErrorMessage("No repository ID specified")
                await MainActor.run { isModelLoading = false }
                return
            }
            
            await MainActor.run {
                loadingStatus = "Downloading model..."
                loadProgress = 0.05
            }
            
            let modelDirectory = try await downloadModel(repoID: repoID)
            self.localModelDirectory = modelDirectory
            
            await MainActor.run {
                loadingStatus = "Model downloaded, preparing to load..."
                loadProgress = 0.4
            }
            
            await loadLocalModel()
            
        } catch {
            await showErrorMessage("Failed to download model: \(error.localizedDescription)")
            await MainActor.run { isModelLoading = false }
        }
    }
    
    // Send a message to the model and get a response
    func sendMessage(_ text: String) async {
        // Add user message
        let userMessage = ChatMessage(id: UUID(), role: .user, content: text)
        
        await MainActor.run {
            messages.append(userMessage)
            conversationStore.addMessageToSelectedConversation(userMessage)
            isGenerating = true
            generationStats = nil
        }
        
        do {
            guard let generator = generator else {
                await showErrorMessage("Text generator not initialized")
                return
            }
            
            // Add assistant message (initially empty)
            let assistantMessageID = UUID()
            let assistantMessage = ChatMessage(id: assistantMessageID, role: .assistant, content: "")
            
            await MainActor.run {
                messages.append(assistantMessage)
                conversationStore.addMessageToSelectedConversation(assistantMessage)
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // These need to be accessed on the main actor to avoid concurrency issues
            actor GenerationMetrics {
                var latencies: [Double] = []
                var newTokenCount: Int = 0
                
                func incrementTokenCount() {
                    newTokenCount += 1
                }
                
                func addLatency(_ value: Double) {
                    latencies.append(value)
                }
                
                func getStats(totalTime: Double) -> GenerationStats {
                    let avgLatency = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
                    let tokensPerSecond = newTokenCount > 0 ? Double(newTokenCount) / totalTime : 0
                    
                    return GenerationStats(
                        tokenCount: newTokenCount,
                        totalTimeSeconds: totalTime,
                        averageLatencyMs: avgLatency,
                        tokensPerSecond: tokensPerSecond
                    )
                }
            }
            
            let metrics = GenerationMetrics()
            
            // Generate text with streaming
            try await generator.generateWithCallback(
                text: text,
                maxNewTokens: maxNewTokens,
                onToken: { token, fullText, prediction in
                    // Update UI with generated text
                    Task { @MainActor in
                        if let index = self.messages.firstIndex(where: { $0.id == assistantMessageID }) {
                            self.messages[index].content = fullText
                            // Also update in conversation store
                            self.conversationStore.updateMessageContent(assistantMessageID, content: fullText)
                        }
                    }
                    
                    // Track performance stats
                    Task {
                        await metrics.incrementTokenCount()
                        if let latency = prediction.latency?.converted(to: .milliseconds).value {
                            await metrics.addLatency(latency)
                        }
                    }
                }
            )
            
            // Calculate generation statistics
            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            let stats = await metrics.getStats(totalTime: totalTime)
            
            await MainActor.run {
                isGenerating = false
                generationStats = stats
            }
            
        } catch {
            await MainActor.run {
                isGenerating = false
            }
            await showErrorMessage("Generation failed: \(error.localizedDescription)")
        }
    }
    
    // Infer tokenizer from model name
    private func inferTokenizer() -> String? {
        switch (repoID ?? localModelPrefix ?? localModelDirectory?.lastPathComponent)?.lowercased() ?? "" {
        case let str where str.contains("llama-2-7b"):
            return "pcuenq/Llama-2-7b-chat-coreml"
        case let str where str.contains("llama-3.2-1b"):
            return "meta-llama/Llama-3.2-1B"
        case let str where str.contains("llama-3.2-3b"):
            return "meta-llama/Llama-3.2-3B"
        default:
            return nil
        }
    }
    
    // Show error message on the main thread
    private func showErrorMessage(_ message: String) async {
        await MainActor.run {
            self.errorMessage = message
            self.showError = true
        }
    }
    
    // Load messages from the selected conversation
    @MainActor
    func loadSelectedConversation() {
        if let conversation = conversationStore.selectedConversation {
            self.messages = conversation.messages
        } else {
            self.messages = []
        }
    }
    
    // Switch to a different conversation
    @MainActor
    func switchConversation(to conversationId: UUID) {
        conversationStore.selectedConversationId = conversationId
        loadSelectedConversation()
    }
    
    // Download model from Hugging Face
    private func downloadModel(repoID: String) async throws -> URL {
        let hub = HubApi()
        let repo = Hub.Repo(id: repoID, type: .models)
        
        let mlmodelcs = ["Llama*.mlmodelc/*", "logit*", "cache*"]
        await MainActor.run {
            self.loadingStatus = "Checking repository \(repoID)..."
            self.loadProgress = 0.08
        }
        
        let filenames = try await hub.getFilenames(from: repo, matching: mlmodelcs)
        
        await MainActor.run {
            self.loadingStatus = "Checking local files..."
            self.loadProgress = 0.1
        }
        
        let localURL = hub.localRepoLocation(repo)
        let localFileURLs = filenames.map {
            localURL.appending(component: $0)
        }
        let anyNotExists = localFileURLs.filter {
            !FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }.count > 0
        
        // swift-transformers doesn't offer a way to know if we're up to date.
        let newestTimestamp = localFileURLs.filter {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }.compactMap {
           let attrs = try! FileManager.default.attributesOfItem(atPath: $0.path(percentEncoded: false))
           return attrs[.modificationDate] as? Date
        }.max() ?? Date.distantFuture
        let lastUploadDate = Date(timeIntervalSince1970: 1723688450)
        let isStale = repoID == "smpanaro/Llama-2-7b-coreml" && newestTimestamp < lastUploadDate
        
        // I would rather not delete things automatically.
        if isStale {
            throw ChatUIError.staleFiles
        }
        
        let needsDownload = anyNotExists || isStale
        guard needsDownload else { 
            await MainActor.run {
                self.loadingStatus = "Using cached model files"
                self.loadProgress = 0.35
            }
            return localURL 
        }
        
        await MainActor.run {
            self.loadingStatus = "Preparing to download from \(repoID)..."
            self.loadProgress = 0.12
        }
        
        if filenames.count == 0 {
            throw ChatUIError.noModelFilesFound
        }
        
        let downloadDir = try await hub.snapshot(from: repo, matching: mlmodelcs) { progress in
            let percent = progress.fractionCompleted * 100
            if !progress.isFinished {
                Task { @MainActor in
                    // Scale progress between 0.15 and 0.35
                    self.loadProgress = 0.15 + (progress.fractionCompleted * 0.2) 
                    self.loadingStatus = "Downloading: \(Int(percent))%"
                }
            }
        }
        
        await MainActor.run {
            self.loadingStatus = "Download complete"
            self.loadProgress = 0.35
        }
        
        return downloadDir
    }
}

struct GenerationStats {
    let tokenCount: Int
    let totalTimeSeconds: Double
    let averageLatencyMs: Double
    let tokensPerSecond: Double
    
    var formattedLatency: String {
        return String(format: "%.2f ms/token", averageLatencyMs)
    }
    
    var formattedThroughput: String {
        return String(format: "%.2f tokens/sec", tokensPerSecond)
    }
}

enum ChatUIError: Error {
    case noModelFilesFound
    case staleFiles
    case generationError
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let role: MessageRole
    var content: String
    var timestamp: Date
    
    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}