import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .assistant {
                avatarView(systemName: "cpu")
                    .foregroundColor(.blue)
                textBubble
                Spacer()
            } else {
                Spacer()
                textBubble
                avatarView(systemName: "person")
                    .foregroundColor(.green)
            }
        }
    }
    
    private var textBubble: some View {
        Text(message.content)
            .padding()
            .background(message.role == .assistant ? Color.gray.opacity(0.2) : Color.blue.opacity(0.8))
            .foregroundColor(message.role == .assistant ? .primary : .white)
            .cornerRadius(12)
            .frame(maxWidth: 280, alignment: message.role == .assistant ? .leading : .trailing)
    }
    
    private func avatarView(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 24))
            .frame(width: 36, height: 36)
            .background(Circle().fill(Color.gray.opacity(0.2)))
    }
}

#Preview {
    VStack {
        ChatBubbleView(message: ChatMessage(id: UUID(), role: .user, content: "Hello, can you help me understand how transformers work?"))
        ChatBubbleView(message: ChatMessage(id: UUID(), role: .assistant, content: "Certainly! Transformers are neural network architectures that use self-attention mechanisms to process sequential data like text. They were introduced in the paper 'Attention is All You Need' and have become foundational for modern NLP."))
    }
    .padding()
}