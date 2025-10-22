import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import Combine

@MainActor
class LLMService: ObservableObject {
    static let shared = LLMService()
    
    @Published var isGenerating = false
    @Published var currentResponse = ""
    
    private var bridge: LLMBridge
    private var currentTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    var baseURL: String {
        let provider = LLMProvider(rawValue: UserDefaults.standard.string(forKey: "selectedProvider") ?? "OLLAMA") ?? .ollama
        switch provider {
        case .ollama:
            return UserDefaults.standard.string(forKey: "ollama_base_url") ?? "http://localhost:11434"
        case .lmstudio:
            return UserDefaults.standard.string(forKey: "lmStudioAddress") ?? "http://localhost:1234"
        case .claude:
            return "https://api.anthropic.com"
        case .openai:
            return "https://api.openai.com"
        }
    }
    
    private var target: LLMTarget {
        return Self.getCurrentTarget()
    }
    
    private static func getCurrentTarget() -> LLMTarget {
        let provider = LLMProvider(rawValue: UserDefaults.standard.string(forKey: "selectedProvider") ?? "OLLAMA") ?? .ollama
        switch provider {
        case .ollama:
            return .ollama
        case .lmstudio:
            return .lmstudio
        case .claude:
            return .claude
        case .openai:
            return .openai
        }
    }
    
    private init() {
        let currentTarget = Self.getCurrentTarget()
        let apiKey: String?

        switch currentTarget {
        case .claude:
            apiKey = try? SecureConfigurationManager.shared.getAPIKey(for: .claude)
            self.bridge = LLMBridge(
                baseURL: "https://api.anthropic.com",
                port: 443,
                target: currentTarget,
                apiKey: apiKey
            )
        case .openai:
            apiKey = try? SecureConfigurationManager.shared.getAPIKey(for: .openai)
            self.bridge = LLMBridge(
                baseURL: "https://api.openai.com",
                port: 443,
                target: currentTarget,
                apiKey: apiKey
            )
        default:
            apiKey = nil
            let baseURLString = UserDefaults.standard.string(forKey: "ollama_base_url") ?? "http://localhost:11434"
            let url = URL(string: baseURLString) ?? URL(string: "http://localhost:11434")!
            let host = url.host ?? "localhost"
            let port = url.port ?? (currentTarget == .lmstudio ? 1234 : 11434)

            self.bridge = LLMBridge(
                baseURL: "http://\(host)",
                port: port,
                target: currentTarget,
                apiKey: apiKey
            )
        }
    }
    
    func updateConfiguration() {
        let currentTarget = target
        let apiKey: String?

        switch currentTarget {
        case .claude:
            apiKey = try? SecureConfigurationManager.shared.getAPIKey(for: .claude)
            self.bridge = bridge.createNewSession(
                baseURL: "https://api.anthropic.com",
                port: 443,
                target: currentTarget,
                apiKey: apiKey
            )
        case .openai:
            apiKey = try? SecureConfigurationManager.shared.getAPIKey(for: .openai)
            self.bridge = bridge.createNewSession(
                baseURL: "https://api.openai.com",
                port: 443,
                target: currentTarget,
                apiKey: apiKey
            )
        default:
            apiKey = nil
            let url = URL(string: baseURL) ?? URL(string: "http://localhost:11434")!
            let host = url.host ?? "localhost"
            let port = url.port ?? (currentTarget == .lmstudio ? 1234 : 11434)

            self.bridge = bridge.createNewSession(
                baseURL: "http://\(host)",
                port: port,
                target: currentTarget,
                apiKey: apiKey
            )
        }

        // Update model parameters
        bridge.temperature = UserDefaults.standard.double(forKey: "temperature")
        bridge.topP = UserDefaults.standard.double(forKey: "topP") != 0 ? UserDefaults.standard.double(forKey: "topP") : 0.9
        bridge.topK = UserDefaults.standard.double(forKey: "topK") != 0 ? UserDefaults.standard.double(forKey: "topK") : 40
    }
    
    func refreshForProviderChange() {
        updateConfiguration()
    }
    
    func generateResponse(prompt: String, image: PlatformImage? = nil, model: String) async throws -> AsyncThrowingStream<String, Error> {
        updateConfiguration()
        
        isGenerating = true
        currentResponse = ""
        
        var platformImage: PlatformImage? = nil
        var selectedModel = model
        
        if let image = image {
            if target == .openai {
                platformImage = image
                selectedModel = "gpt-4o"
            } else {
                platformImage = image
            }
        }
        
        return AsyncThrowingStream { continuation in
            currentTask = Task {
                do {
                    let chatHistory = try await fetchChatHistory()
                    
                    let instruction = UserDefaults.standard.string(forKey: "llmInstruction") ?? "You are a helpful assistant."
                    var fullPrompt = instruction + "\n\n"
                    
                    for chat in chatHistory {
                        fullPrompt += "User: \(chat.question)\n"
                        fullPrompt += "Assistant: \(chat.answer)\n\n"
                    }
                    
                    fullPrompt += "User: \(prompt)\n"
                    fullPrompt += "Assistant:"
                    
                    let stream = bridge.sendMessageStream(
                        content: fullPrompt,
                        image: platformImage,
                        model: selectedModel
                    )
                    
                    for try await chunk in stream {
                        if Task.isCancelled { break }
                        currentResponse += chunk
                        continuation.yield(chunk)
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
                
                isGenerating = false
            }
            
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.currentTask?.cancel()
                    self.isGenerating = false
                }
            }
        }
    }
    
    func listModels() async throws -> [String] {
        updateConfiguration()
        let models = await bridge.getAvailableModels()
        return models
    }
    
    func cancelGeneration() {
        currentTask?.cancel()
        bridge.cancelGeneration()
        isGenerating = false
    }
    
    private func fetchChatHistory() async throws -> [(question: String, answer: String)] {
        let groupId = ChatViewModel.shared.chatId.uuidString
        let results = try DatabaseManager.shared.fetchQuestionsByGroupId(groupId)
        return results.map { (question: $0.question, answer: $0.answer) }
    }
}

