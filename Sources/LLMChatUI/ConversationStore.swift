import Foundation
import SwiftUI

// MARK: - Conversation Model
struct Conversation: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var messages: [ChatMessage]
    var systemPrompt: String
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), 
         title: String = "New Conversation", 
         messages: [ChatMessage] = [], 
         systemPrompt: String = "", 
         createdAt: Date = Date(), 
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.systemPrompt = systemPrompt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    mutating func updateTitle(basedOnContent content: String) {
        if title == "New Conversation" && !content.isEmpty {
            // Generate title based on first few words of content
            let words = content.split(separator: " ")
            let titleWords = words.prefix(3).joined(separator: " ")
            self.title = titleWords.count > 0 ? titleWords + "..." : "New Conversation"
        }
    }
}

// MARK: - Conversation Store
class ConversationStore: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var selectedConversationId: UUID?
    
    private let saveKey = "savedConversations"
    
    var selectedConversation: Conversation? {
        get {
            if let id = selectedConversationId {
                return conversations.first { $0.id == id }
            }
            return nil
        }
    }
    
    init() {
        loadConversations()
        
        // If no conversations exist, create one
        if conversations.isEmpty {
            createNewConversation()
        }
    }
    
    func createNewConversation() {
        let newConversation = Conversation()
        conversations.append(newConversation)
        selectedConversationId = newConversation.id
        saveConversations()
    }
    
    func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        
        // If we deleted the selected conversation, select another one
        if selectedConversationId == id {
            selectedConversationId = conversations.first?.id
        }
        
        saveConversations()
    }
    
    func addMessageToSelectedConversation(_ message: ChatMessage) {
        guard let index = conversations.firstIndex(where: { $0.id == selectedConversationId }) else { return }
        
        conversations[index].messages.append(message)
        conversations[index].updatedAt = Date()
        
        // If this is the first user message, update the conversation title
        if conversations[index].title == "New Conversation" && message.role == .user {
            conversations[index].updateTitle(basedOnContent: message.content)
        }
        
        saveConversations()
    }
    
    func updateSystemPrompt(_ prompt: String) {
        guard let index = conversations.firstIndex(where: { $0.id == selectedConversationId }) else { return }
        
        conversations[index].systemPrompt = prompt
        conversations[index].updatedAt = Date()
        saveConversations()
    }
    
    // MARK: - Persistence
    private func saveConversations() {
        if let encoded = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadConversations() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = decoded
            selectedConversationId = conversations.first?.id
        }
    }
}