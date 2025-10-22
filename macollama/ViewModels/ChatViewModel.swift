import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum ChatError: LocalizedError {
    case loadFailed(String)
    case saveFailed(String)
    case databaseError(Error)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .loadFailed(let groupId):
            return "Failed to load chat: \(groupId)"
        case .saveFailed(let reason):
            return "Failed to save: \(reason)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid data format"
        }
    }
}

class ChatViewModel: ObservableObject {
    static let shared = ChatViewModel()

    @Published var messages: [ChatMessage] = []
    @Published var selectedImage: PlatformImage?
    @Published var messageText: String = ""
    @Published var chatId = UUID()
    @Published var shouldFocusTextField: Bool = false
    @Published var chatProvider: LLMProvider = .ollama
    @Published var chatModel: String? = nil
    @Published var error: Error?
    @Published var showingError = false

    private init() {}

    private func normalizedProvider(from string: String) -> LLMProvider? {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "ollama", "ollma", "ollama server":
            return .ollama
        case "lmstudio", "lm studio":
            return .lmstudio
        case "claude", "anthropic":
            return .claude
        case "openai", "gpt":
            return .openai
        default:
            return LLMProvider(rawValue: string)
        }
    }
    
    func startNewChat() {
        messages.removeAll()
        selectedImage = nil
        messageText = ""
        chatId = UUID()
        // Use a task to set focus flag asynchronously to prevent update loops
        Task { @MainActor in
            shouldFocusTextField = true
        }
        // Note: Keep the current chatProvider and chatModel for the new chat
    }
    
    func updateProviderAndModel(_ provider: LLMProvider, _ model: String?) {
        self.chatProvider = provider
        self.chatModel = model
    }
    
    func saveProviderAndModel() {
        guard chatId != UUID() else { return }

        Task {
            do {
                try DatabaseManager.shared.updateChatProviderAndModel(
                    groupId: chatId.uuidString,
                    provider: chatProvider.rawValue,
                    model: chatModel
                )
            } catch {
                await MainActor.run {
                    self.error = ChatError.saveFailed("Failed to save provider and model settings")
                    self.showingError = true
                }
            }
        }
    }
    
    @MainActor
    func loadChat(groupId: String) {
        do {
            let results = try DatabaseManager.shared.fetchQuestionsByGroupId(groupId)
            
            messages = []
            
            let dateFormatter = ISO8601DateFormatter()
            
            for (_, result) in results.enumerated() {
                
                var image: PlatformImage? = nil
                if let imageBase64 = result.image,
                   let imageData = Data(base64Encoded: imageBase64) {
                    #if os(macOS)
                    image = NSImage(data: imageData)
                    #elseif os(iOS)
                    image = UIImage(data: imageData)
                    #endif
                }
                
                let timestamp = dateFormatter.date(from: result.created) ?? Date()
                
                messages.append(ChatMessage(
                    id: result.id * 2,
                    content: result.question,
                    isUser: true,
                    timestamp: timestamp,
                    image: image,
                    engine: result.engine
                ))
                
                messages.append(ChatMessage(
                    id: result.id * 2 + 1,
                    content: result.answer,
                    isUser: false,
                    timestamp: timestamp,
                    image: nil,
                    engine: result.engine
                ))
            }
            
            chatId = UUID(uuidString: groupId) ?? UUID()
            
            // Load provider and model settings for this chat
            do {
                let (provider, model) = try DatabaseManager.shared.getChatProviderAndModel(groupId: groupId)
                if let providerString = provider {
                    if let providerEnum = normalizedProvider(from: providerString) {
                        self.chatProvider = providerEnum
                    }
                }
                if let model = model {
                    self.chatModel = model
                }
            } catch {
                self.error = ChatError.databaseError(error)
                self.showingError = true
            }
        } catch {
            self.error = ChatError.loadFailed(groupId)
            self.showingError = true
        }
    }
} 
