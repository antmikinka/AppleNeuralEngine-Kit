import SwiftUI

struct ConversationListView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack {
            // Header with new conversation button
            HStack {
                Text("Conversations")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    viewModel.conversationStore.createNewConversation()
                    viewModel.loadSelectedConversation()
                }) {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Conversation list
            List(viewModel.conversationStore.conversations) { conversation in
                ConversationRow(
                    conversation: conversation,
                    isSelected: viewModel.conversationStore.selectedConversationId == conversation.id,
                    onSelect: {
                        viewModel.switchConversation(to: conversation.id)
                    },
                    onDelete: {
                        viewModel.conversationStore.deleteConversation(conversation.id)
                        viewModel.loadSelectedConversation()
                    }
                )
            }
            .listStyle(.sidebar)
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.headline)
                
                Text(formatDate(conversation.updatedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if isSelected {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .swipeActions {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}