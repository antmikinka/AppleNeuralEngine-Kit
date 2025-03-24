import Foundation
import Tokenizers
import Hub
import CoreML
import SwiftUI
import LLMKit

class ChatViewModel: ObservableObject {
    // Model state
    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var messages: [ChatMessage] = []
    @Published var loadingStatus = "Loading model..."
    @Published var showError = false
    @Published var errorMessage = ""
    
    // Model configuration
    var repoID: String?
    var localModelDirectory: URL?
    var localModelPrefix: String?
    var cacheProcessorModelName = "cache-processor.mlmodelc"
    var logitProcessorModelName = "logit-processor.mlmodelc" 
    var tokenizerName: String?
    var maxNewTokens = 60
    
    // Core components
    private var pipeline: ModelPipeline?
    private var tokenizer: Tokenizer?
    private var generator: TextGenerator?
    
    // Load a model from a local directory
    func loadLocalModel() async {
        await MainActor.run {
            isModelLoaded = false
            loadingStatus = "Loading model..."
        }
        
        do {
            guard let modelDirectory = localModelDirectory else {
                await showErrorMessage("No model directory specified")
                return
            }
            
            await MainActor.run {
                loadingStatus = "Inferring tokenizer..."
            }
            
            guard let tokenizerName = tokenizerName ?? inferTokenizer() else {
                await showErrorMessage("Unable to infer tokenizer. Please configure tokenizer.")
                return
            }
            
            await MainActor.run {
                loadingStatus = "Loading model pipeline..."
            }
            
            let pipeline = try ModelPipeline.from(
                folder: modelDirectory,
                modelPrefix: localModelPrefix,
                cacheProcessorModelName: cacheProcessorModelName,
                logitProcessorModelName: logitProcessorModelName
            )
            
            await MainActor.run {
                loadingStatus = "Loading tokenizer..."
            }
            
            let tokenizer = try await AutoTokenizer.from(pretrained: tokenizerName, hubApi: .init())
            
            // Initialize text generator
            let generator = TextGenerator(pipeline: pipeline, tokenizer: tokenizer)
            
            // Store references
            self.pipeline = pipeline
            self.tokenizer = tokenizer
            self.generator = generator
            
            await MainActor.run {
                self.isModelLoaded = true
            }
            
        } catch {
            await showErrorMessage("Failed to load model: \(error.localizedDescription)")
        }
    }
    
    // Load a model from Hugging Face
    func loadRemoteModel() async {
        await MainActor.run {
            isModelLoaded = false
            loadingStatus = "Checking Hugging Face repo..."
        }
        
        do {
            guard let repoID = repoID else {
                await showErrorMessage("No repository ID specified")
                return
            }
            
            await MainActor.run {
                loadingStatus = "Downloading model..."
            }
            
            let modelDirectory = try await downloadModel(repoID: repoID)
            self.localModelDirectory = modelDirectory
            
            await loadLocalModel()
            
        } catch {
            await showErrorMessage("Failed to download model: \(error.localizedDescription)")
        }
    }
    
    // Send a message to the model and get a response
    func sendMessage(_ text: String) async {
        // Add user message
        let userMessage = ChatMessage(id: UUID(), role: .user, content: text)
        
        await MainActor.run {
            messages.append(userMessage)
            isGenerating = true
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
            }
            
            var fullGeneratedText = ""
            
            // Generate text with streaming
            try await generator.generateWithCallback(
                text: text,
                maxNewTokens: maxNewTokens,
                onToken: { token, fullText in
                    Task { @MainActor in
                        fullGeneratedText = fullText
                        if let index = self.messages.firstIndex(where: { $0.id == assistantMessageID }) {
                            self.messages[index].content = fullText
                        }
                    }
                }
            )
            
            await MainActor.run {
                isGenerating = false
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
    
    // Download model from Hugging Face
    private func downloadModel(repoID: String) async throws -> URL {
        let hub = HubApi()
        let repo = Hub.Repo(id: repoID, type: .models)
        
        let mlmodelcs = ["Llama*.mlmodelc/*", "logit*", "cache*"]
        let filenames = try await hub.getFilenames(from: repo, matching: mlmodelcs)
        
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
        guard needsDownload else { return localURL }
        
        await MainActor.run {
            self.loadingStatus = "Downloading from \(repoID)..."
        }
        
        if filenames.count == 0 {
            throw ChatUIError.noModelFilesFound
        }
        
        let downloadDir = try await hub.snapshot(from: repo, matching: mlmodelcs) { progress in
            let percent = progress.fractionCompleted * 100
            if !progress.isFinished {
                Task { @MainActor in
                    self.loadingStatus = "Downloading: \(Int(percent))%"
                }
            }
        }
        
        await MainActor.run {
            self.loadingStatus = "Download complete"
        }
        
        return downloadDir
    }
}

enum ChatUIError: Error {
    case noModelFilesFound
    case staleFiles
    case generationError
}

enum MessageRole {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    var content: String
}