//
//  swift_llm_bridge.swift
//  swift-llm-bridge
//
//  Created by BillyPark on 6/1/25.
//

import Foundation
import Combine

#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

public enum LLMTarget: Sendable {
    case ollama
    case lmstudio
    case claude
    case openai
}

@available(iOS 15.0, macOS 12.0, *)
@MainActor
public class LLMBridge: ObservableObject {
    
    public struct Message: Identifiable, Equatable {
        public let id = UUID()
        public var content: String
        public let isUser: Bool
        public let timestamp: Date
        public let image: PlatformImage?
        
        public static func == (lhs: Message, rhs: Message) -> Bool {
            return lhs.id == rhs.id
        }
        
        public init(content: String, isUser: Bool, image: PlatformImage? = nil, timestamp: Date = Date()) {
            self.content = content
            self.isUser = isUser
            self.image = image
            self.timestamp = timestamp
        }
    }
    
    @Published public var messages: [Message] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String? = nil
    @Published public var currentResponse: String = ""
    
    private var baseURL: URL
    private var port: Int
    private let target: LLMTarget
    private let apiKey: String?
    private var generationTask: Task<Void, Never>?
    private let defaultModel = "llama3.2"
    private var tempResponse: String = ""
    var temperature: Double
    var topP: Double
    var topK: Double
    
    private var getDefaultModel: String {
        switch target {
        case .ollama:
            return "llama3.2"
        case .lmstudio:
            return "llama3.2"
        case .claude:
            return "claude-3-5-sonnet-20241022"
        case .openai:
            return "gpt-4"
        }
    }
    
    private let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300.0
        configuration.timeoutIntervalForResource = 600.0
        configuration.waitsForConnectivity = true
        #if canImport(UIKit)
        configuration.allowsCellularAccess = true
        #endif
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()
    
    public init(baseURL: String = "http://localhost", port: Int = 11434, target: LLMTarget = .ollama, apiKey: String? = nil) {
        if target == .claude {
            guard let url = URL(string: "https://api.anthropic.com") else {
                fatalError("Invalid Claude API URL")
            }
            self.baseURL = url
            self.port = 443
        } else if target == .openai {
            guard let url = URL(string: "https://api.openai.com") else {
                fatalError("Invalid OpenAI API URL")
            }
            self.baseURL = url
            self.port = 443
        } else {
            guard let url = URL(string: "\(baseURL):\(port)") else {
                fatalError("Invalid base URL")
            }
            self.baseURL = url
            self.port = port
        }
        self.target = target
        self.apiKey = apiKey
        self.temperature = UserDefaults.standard.double(forKey: "temperature")
        self.topP = UserDefaults.standard.double(forKey: "topP") != 0 ? UserDefaults.standard.double(forKey: "topP") : 0.9
        self.topK = UserDefaults.standard.double(forKey: "topK") != 0 ? UserDefaults.standard.double(forKey: "topK") : 40
    }
    
    public func createNewSession(baseURL: String, port: Int, target: LLMTarget, apiKey: String? = nil) -> LLMBridge {
        let bridge = LLMBridge(baseURL: baseURL, port: port, target: target, apiKey: apiKey)
        bridge.temperature = self.temperature
        bridge.topP = self.topP
        bridge.topK = self.topK
        return bridge
    }
        
    public func getAvailableModels() async -> [String] {
        let endpoint = getModelsEndpoint()
        let requestURL = baseURL.appendingPathComponent(endpoint)
        
        do {
            var request = URLRequest(url: requestURL)
            request.timeoutInterval = 10.0  
            
            if target == .claude {
                guard let key = apiKey else {
                    return []
                }
                request.addValue("\(key)", forHTTPHeaderField: "x-api-key")
                request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            if target == .openai {
                guard let key = apiKey else {
                    return []
                }
                request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            let (data, _) = try await URLSession.shared.data(for: request)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return []
            }
            
            switch target {
            case .ollama:
                if let models = json["models"] as? [[String: Any]] {
                    let modelNames = models.compactMap { $0["name"] as? String }
                    return modelNames
                }
            case .lmstudio:
                if let data = json["data"] as? [[String: Any]] {
                    let modelIds = data.compactMap { $0["id"] as? String }
                    return modelIds
                }
            case .claude:
                if let data = json["data"] as? [[String: Any]] {
                    let modelIds = data.compactMap { $0["id"] as? String }
                    return modelIds
                }
            case .openai:
                if let data = json["data"] as? [[String: Any]] {
                    let modelIds = data.compactMap { $0["id"] as? String }
                    return modelIds
                }
            }
            
            return []
            
        } catch {
            return []
        }
    }
        
    public func sendMessage(content: String, image: PlatformImage? = nil, model: String? = nil) async throws -> Message {
        isLoading = true
        errorMessage = nil
        tempResponse = ""
        currentResponse = ""
        
        let userMessage = Message(content: content, isUser: true, image: image)
        messages.append(userMessage)
        
        generationTask?.cancel()
        
        var aiMessage: Message?
        let selectedModel = model ?? getDefaultModel
        
        generationTask = Task {
            defer { isLoading = false }
            
            do {
                let endpoint = getChatEndpoint(forModel: selectedModel)
                let requestURL = baseURL.appendingPathComponent(endpoint)
                var request = URLRequest(url: requestURL)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")

                // gpt-5는 비스트리밍으로 처리
                if target == .openai, selectedModel.lowercased().contains("gpt-5") {
                    let text = try await self.fetchOpenAIResponses(content: content, model: selectedModel, image: image)
                    tempResponse = text
                } else {
                    if target == .lmstudio {
                        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
                        request.addValue("keep-alive", forHTTPHeaderField: "Connection")
                    } else {
                        request.addValue("application/json", forHTTPHeaderField: "Accept")
                    }
                    
                    if target == .claude {
                        guard let key = apiKey else {
                            throw NSError(domain: "LLMBridgeError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Claude API key is required"])
                        }
                        request.addValue("\(key)", forHTTPHeaderField: "x-api-key")
                        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
                    }
                    
                    if target == .openai {
                        guard let key = apiKey else {
                            throw NSError(domain: "LLMBridgeError", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key is required"])
                        }
                        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
                        request.addValue("keep-alive", forHTTPHeaderField: "Connection")
                        if request.url?.path.contains("/v1/responses") == true {
                            request.addValue("responses-2024-12-17", forHTTPHeaderField: "OpenAI-Beta")
                        }
                    }
                    
                    request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
                    request.timeoutInterval = 300.0
                    
                    let requestData = try createChatRequest(content: content, model: selectedModel, image: image)
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
                    if target == .openai, request.url?.path.contains("/v1/responses") == true, let body = request.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
                        print("[LLMBridge] OpenAI Responses payload:", bodyStr)
                    }
                    
                    try await self.processStream(request: request)
                }
                
                if !tempResponse.isEmpty {
                    let message = Message(content: tempResponse, isUser: false, image: nil, timestamp: Date())
                    messages.append(message)
                    aiMessage = message
                    
                    tempResponse = ""
                    currentResponse = ""
                }
                
            } catch {
                errorMessage = error.localizedDescription
                
                if !Task.isCancelled && !tempResponse.isEmpty {
                    let message = Message(content: tempResponse + "\nAn error occurred.", isUser: false, image: nil, timestamp: Date())
                    messages.append(message)
                    aiMessage = message
                    
                    tempResponse = ""
                    currentResponse = ""
                }
            }
        }
        
        await generationTask?.value
        
        return aiMessage ?? Message(content: "Failed to generate response.", isUser: false, image: nil, timestamp: Date())
    }
    
    public func sendMessageStream(content: String, image: PlatformImage? = nil, model: String? = nil) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task { @MainActor in
                isLoading = true
                errorMessage = nil
                tempResponse = ""
                currentResponse = ""
                
                let userMessage = Message(content: content, isUser: true, image: image)
                messages.append(userMessage)
                
                generationTask?.cancel()
                
                let selectedModel = model ?? getDefaultModel
                
                generationTask = Task {
                    defer { 
                        Task { @MainActor in
                            isLoading = false
                        }
                    }
                    
                    do {
                        // 사전 요청 객체 생성
                        let endpoint = getChatEndpoint(forModel: selectedModel)
                        let requestURL = baseURL.appendingPathComponent(endpoint)
                        var request = URLRequest(url: requestURL)
                        request.httpMethod = "POST"
                        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

                        // gpt-5 스트리밍은 조직 인증 필요. 인증 없는 경우 non-stream 폴백
                        if target == .openai, selectedModel.lowercased().contains("gpt-5") {
                            do {
                                // 먼저 스트리밍을 시도
                                if let key = apiKey {
                                    request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                                }
                                request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
                                request.addValue("keep-alive", forHTTPHeaderField: "Connection")
                                if request.url?.path.contains("/v1/responses") == true {
                                    request.addValue("responses-2024-12-17", forHTTPHeaderField: "OpenAI-Beta")
                                }
                                request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
                                request.timeoutInterval = 300.0
                                let requestData = try createChatRequest(content: content, model: selectedModel, image: image)
                                request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
                                try await self.processStreamWithContinuation(request: request, continuation: continuation)
                            } catch {
                                // 조직 미검증 등으로 스트리밍 오류 시 non-stream으로 폴백
                                let text = try await self.fetchOpenAIResponses(content: content, model: selectedModel, image: image)
                                continuation.yield(text)
                            }
                        } else {
                            // 기존 스트리밍 경로
                            if target == .lmstudio {
                                request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
                                request.addValue("keep-alive", forHTTPHeaderField: "Connection")
                            } else {
                                request.addValue("application/json", forHTTPHeaderField: "Accept")
                            }
                            
                            if target == .claude {
                                guard let key = apiKey else {
                                    throw NSError(domain: "LLMBridgeError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Claude API key is required"])
                                }
                                request.addValue("\(key)", forHTTPHeaderField: "x-api-key")
                                request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                                request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
                            }
                            
                            if target == .openai {
                                guard let key = apiKey else {
                                    throw NSError(domain: "LLMBridgeError", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key is required"])
                                }
                                request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                                request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
                                request.addValue("keep-alive", forHTTPHeaderField: "Connection")
                                if request.url?.path.contains("/v1/responses") == true {
                                    request.addValue("responses-2024-12-17", forHTTPHeaderField: "OpenAI-Beta")
                                }
                            }
                            
                            request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
                            request.timeoutInterval = 300.0
                            
                            let requestData = try createChatRequest(content: content, model: selectedModel, image: image)
                            request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
                            if target == .openai, request.url?.path.contains("/v1/responses") == true, let body = request.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
                                print("[LLMBridge] OpenAI Responses payload:", bodyStr)
                            }
                            
                            try await self.processStreamWithContinuation(request: request, continuation: continuation)
                        }
                        
                        if !tempResponse.isEmpty {
                            let message = Message(content: tempResponse, isUser: false, image: nil, timestamp: Date())
                            await MainActor.run {
                                messages.append(message)
                            }
                            
                            tempResponse = ""
                            currentResponse = ""
                        }
                        
                        continuation.finish()
                        
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                        }
                        
                        if !Task.isCancelled && !tempResponse.isEmpty {
                            let message = Message(content: tempResponse + "\nAn error occurred.", isUser: false, image: nil, timestamp: Date())
                            await MainActor.run {
                                messages.append(message)
                            }
                            
                            tempResponse = ""
                            currentResponse = ""
                        }
                        
                        continuation.finish(throwing: error)
                    }
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.generationTask?.cancel()
                    self.isLoading = false
                }
            }
        }
    }
    
    public func cancelGeneration() {
        generationTask?.cancel()
        
        if !tempResponse.isEmpty {
            let message = Message(content: tempResponse + "\nCancelled by user.", isUser: false, image: nil, timestamp: Date())
            messages.append(message)
            
            tempResponse = ""
            currentResponse = ""
        }
    }
    
    public func clearMessages() {
        messages.removeAll()
        errorMessage = nil
        tempResponse = ""
        currentResponse = ""
    }
    
    private func getModelsEndpoint() -> String {
        switch target {
        case .ollama:
            return "api/tags"
        case .lmstudio:
            return "v1/models"
        case .claude:
            return "v1/models"
        case .openai:
            return "v1/models"
        }
    }
    
    private func getChatEndpoint(forModel model: String?) -> String {
        switch target {
        case .ollama:
            return "api/chat"
        case .lmstudio:
            return "v1/chat/completions"
        case .claude:
            return "v1/messages"
        case .openai:
            if let model = model?.lowercased(), model.contains("gpt-5") {
                return "v1/responses"
            }
            return "v1/chat/completions"
        }
    }
    
    private func createChatRequest(content: String, model: String, image: PlatformImage?) throws -> [String: Any] {
        switch target {
        case .ollama:
            return createOllamaChatRequest(content: content, model: model, image: image)
        case .lmstudio:
            return createLMStudioChatRequest(content: content, model: model, image: image)
        case .claude:
            return createClaudeChatRequest(content: content, model: model, image: image)
        case .openai:
            if model.lowercased().hasPrefix("gpt-5") {
                return createOpenAIResponsesRequest(content: content, model: model, image: image)
            }
            return createOpenAIChatRequest(content: content, model: model, image: image)
        }
    }
    
    private func createOllamaChatRequest(content: String, model: String, image: PlatformImage?) -> [String: Any] {
        var chatMessages: [[String: Any]] = []
        
        for message in messages.dropLast() {
            let role = message.isUser ? "user" : "assistant"
            chatMessages.append(["role": role, "content": message.content])
        }
        
        var currentUserMessage: [String: Any] = [
            "role": "user",
            "content": content
        ]
        
        if let userImage = image,
           let imageBase64 = encodeImageToBase64(userImage) {
            currentUserMessage["images"] = [imageBase64]
        }
        
        chatMessages.append(currentUserMessage)
        
        return [
            "model": model,
            "messages": chatMessages,
            "stream": true,
            "temperature": temperature,
            "top_p": topP,
            "top_k": Int(topK)
        ]
    }
    
    private func createLMStudioChatRequest(content: String, model: String, image: PlatformImage?) -> [String: Any] {
        var chatMessages: [[String: Any]] = []
        
        for message in messages.dropLast() {
            let role = message.isUser ? "user" : "assistant"
            let messageDict: [String: Any] = [
                "role": role,
                "content": message.content
            ]
            chatMessages.append(messageDict)
        }
        
        var currentUserMessage: [String: Any] = [
            "role": "user"
        ]
        
        if let userImage = image,
           let imageBase64 = encodeImageToBase64(userImage) {
            let imageContent: [String: Any] = [
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(imageBase64)"
                ]
            ]
            let textContent: [String: Any] = [
                "type": "text",
                "text": content
            ]
            currentUserMessage["content"] = [textContent, imageContent]
        } else {
            currentUserMessage["content"] = content
        }
        
        chatMessages.append(currentUserMessage)
        
        return [
            "model": model,
            "messages": chatMessages,
            "stream": true,
            "temperature": 0.7,
            "max_tokens": 2048
        ]
    }
    
    private func createClaudeChatRequest(content: String, model: String, image: PlatformImage?) -> [String: Any] {
        var claudeMessages: [[String: Any]] = []
        
        for message in messages.dropLast() {
            let role = message.isUser ? "user" : "assistant"
            claudeMessages.append(["role": role, "content": message.content])
        }
        
        var currentContent: [[String: Any]] = []
        
        if let userImage = image,
           let imageBase64 = encodeImageToBase64(userImage) {
            currentContent.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": imageBase64
                ]
            ])
        }
        
        currentContent.append([
            "type": "text",
            "text": content
        ])
        
        claudeMessages.append([
            "role": "user",
            "content": currentContent
        ])
        
        return [
            "model": model,
            "messages": claudeMessages,
            "max_tokens": 4096,
            "stream": true,
            "temperature": 0.7
        ]
    }
    
    private func createOpenAIChatRequest(content: String, model: String, image: PlatformImage?) -> [String: Any] {
        var chatMessages: [[String: Any]] = []
        
        for message in messages.dropLast() {
            let role = message.isUser ? "user" : "assistant"
            chatMessages.append(["role": role, "content": message.content])
        }
        
        var currentUserMessage: [String: Any] = [
            "role": "user"
        ]
        
        if let userImage = image,
           let imageBase64 = encodeImageToBase64(userImage) {
            let imageContent: [String: Any] = [
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(imageBase64)"
                ]
            ]
            let textContent: [String: Any] = [
                "type": "text",
                "text": content
            ]
            currentUserMessage["content"] = [textContent, imageContent]
        } else {
            currentUserMessage["content"] = content
        }
        
        chatMessages.append(currentUserMessage)
        
        return [
            "model": model,
            "messages": chatMessages,
            "stream": true,
            "temperature": 0.7,
            "max_tokens": 4096
        ]
    }

    private func createOpenAIResponsesRequest(content: String, model: String, image: PlatformImage?, stream: Bool = true) -> [String: Any] {
        var userContent: [[String: Any]] = []
        userContent.append([
            "type": "input_text",
            "text": content
        ])
        
        if let userImage = image,
           let imageBase64 = encodeImageToBase64(userImage) {
            userContent.append([
                "type": "input_image",
                "image_url": "data:image/jpeg;base64,\(imageBase64)"
            ])
        }
        
        let input: [[String: Any]] = [[
            "role": "user",
            "content": userContent
        ]]
        
        return [
            "model": model,
            "input": input,
            "stream": stream
        ]
    }

    private func parseOpenAIResponsesBody(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }
        // Preferred: traverse output -> message -> content -> output_text
        if let outputs = json["output"] as? [[String: Any]] {
            var combined = ""
            for out in outputs {
                if let type = out["type"] as? String, type == "message",
                   let contents = out["content"] as? [[String: Any]] {
                    for part in contents {
                        if let pType = part["type"] as? String,
                           (pType == "output_text" || pType == "text"),
                           let text = part["text"] as? String {
                            combined += text
                        }
                    }
                }
                if let pType = out["type"] as? String,
                   (pType == "output_text" || pType == "text"),
                   let text = out["text"] as? String {
                    combined += text
                }
            }
            if !combined.isEmpty { return combined }
        }
        // Fallbacks
        if let outputText = json["output_text"] as? String { return outputText }
        if let content = json["content"] as? [[String: Any]] {
            var combined = ""
            for item in content {
                if let type = item["type"] as? String,
                   (type == "output_text" || type == "text"),
                   let text = item["text"] as? String { combined += text }
            }
            if !combined.isEmpty { return combined }
        }
        return String(describing: json)
    }

    private func fetchOpenAIResponses(content: String, model: String, image: PlatformImage?) async throws -> String {
        let endpoint = "v1/responses"
        let requestURL = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if let key = apiKey { request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        request.addValue("responses-2024-12-17", forHTTPHeaderField: "OpenAI-Beta")
        let body = createOpenAIResponsesRequest(content: content, model: model, image: image, stream: false)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let detail = parseHTTPErrorData(data) ?? ""
            let code = (response as? HTTPURLResponse)?.statusCode ?? 400
            throw NSError(domain: "LLMBridgeError", code: code, userInfo: [NSLocalizedDescriptionKey: detail.isEmpty ? "HTTP \(code)" : detail])
        }
        if let text = parseOpenAIResponsesBody(data) {
            return text
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func parseHTTPErrorData(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }
        if let error = json["error"] as? [String: Any] {
            if let message = error["message"] as? String { return message }
            if let code = error["code"] as? String { return code }
        }
        if let message = json["message"] as? String { return message }
        return nil
    }

    private func makeDetailedHTTPError(for request: URLRequest, statusCode: Int) async -> Error {
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let detail = parseHTTPErrorData(data) ?? ""
            let msg = detail.isEmpty ? "Server error: HTTP \(statusCode)" : "HTTP \(statusCode): \(detail)"
            return NSError(domain: "LLMBridgeError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        } catch {
            return NSError(domain: "LLMBridgeError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: HTTP \(statusCode)"])
        }
    }
    
    private func processStream(request: URLRequest) async throws {
        let (asyncBytes, response) = try await urlSession.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw await makeDetailedHTTPError(for: request, statusCode: httpResponse.statusCode)
        }
        
        do {
            for try await line in asyncBytes.lines {
                if Task.isCancelled { break }
                
                if line.isEmpty { continue }
                
                await processStreamLine(line)
            }
        } catch {
            if !Task.isCancelled {
                throw error
            }
        }
    }
    
    private func processStreamLine(_ line: String) async {
        var jsonLine = line
        
        if target == .lmstudio {
            
            if line.hasPrefix("data: ") {
                jsonLine = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                if jsonLine == "[DONE]" || jsonLine.isEmpty { 
                    return
                }
            } else if line.hasPrefix("event:") || line.hasPrefix(":") || line.isEmpty {
                return
            } else if !line.hasPrefix("{") {
                return
            }
        }
        
        if target == .claude {
            if line.hasPrefix("data: ") {
                jsonLine = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                if jsonLine == "[DONE]" || jsonLine.isEmpty {
                    return
                }
            } else if line.hasPrefix("event:") || line.hasPrefix(":") || line.isEmpty {
                return
            } else if !line.hasPrefix("{") {
                return
            }
        }
        
        if target == .openai {
            if line.hasPrefix("data: ") {
                jsonLine = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                if jsonLine == "[DONE]" || jsonLine.isEmpty {
                    return
                }
            } else if line.hasPrefix("event:") || line.hasPrefix(":") || line.isEmpty {
                return
            } else if !line.hasPrefix("{") {
                return
            }
        }
        
        guard !jsonLine.isEmpty,
              let data = jsonLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        switch target {
        case .ollama:
            await processOllamaStream(json)
        case .lmstudio:
            await processLMStudioStream(json)
        case .claude:
            await processClaudeStream(json)
        case .openai:
            await processOpenAIChatStream(json)
        }
    }
    
    private func processOllamaStream(_ json: [String: Any]) async {
        if let message = json["message"] as? [String: Any],
           let content = message["content"] as? String {
            tempResponse += content
            await MainActor.run {
                currentResponse = tempResponse
            }
        }
        
        if let done = json["done"] as? Bool, done {
            return
        }
    }
    
    private func processLMStudioStream(_ json: [String: Any]) async {
        
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let delta = firstChoice["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            tempResponse += content
            await MainActor.run {
                currentResponse = tempResponse
            }
        }
        
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let finishReason = firstChoice["finish_reason"] as? String,
           finishReason == "stop" {
            return
        }
    }
    
    private func processClaudeStream(_ json: [String: Any]) async {
        
        if let type = json["type"] as? String {
            switch type {
            case "content_block_delta":
                if let delta = json["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    tempResponse += text
                    await MainActor.run {
                        currentResponse = tempResponse
                    }
                }
            case "message_stop":
                return
            default:
                break
            }
        }
    }
    
    private func processOpenAIChatStream(_ json: [String: Any]) async {
        // Chat Completions 스트림 형식
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let delta = firstChoice["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            tempResponse += content
            await MainActor.run {
                currentResponse = tempResponse
            }
            return
        }
        // Responses API 스트림 형식
        if let type = json["type"] as? String {
            if type == "response.output_text.delta", let delta = json["delta"] as? String {
                tempResponse += delta
                await MainActor.run {
                    currentResponse = tempResponse
                }
                return
            }
            if type == "response.completed" {
                return
            }
        }
    }
    
    private func processStreamWithContinuation(request: URLRequest, continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let (asyncBytes, response) = try await urlSession.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw await makeDetailedHTTPError(for: request, statusCode: httpResponse.statusCode)
        }
        
        do {
            for try await line in asyncBytes.lines {
                if Task.isCancelled { break }
                
                if line.isEmpty { continue }
                
                await processStreamLineWithContinuation(line, continuation: continuation)
            }
        } catch {
            if !Task.isCancelled {
                throw error
            }
        }
    }
    
    private func processStreamLineWithContinuation(_ line: String, continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        var jsonLine = line
        
        if target == .lmstudio {
            if line.hasPrefix("data: ") {
                jsonLine = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if jsonLine == "[DONE]" || jsonLine.isEmpty { 
                    return 
                }
            } else if line.hasPrefix("event:") || line.hasPrefix(":") || line.isEmpty {
                return
            } else if !line.hasPrefix("{") {
                return
            }
        }
        
        if target == .claude {
            if line.hasPrefix("data: ") {
                jsonLine = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if jsonLine == "[DONE]" || jsonLine.isEmpty {
                    return
                }
            } else if line.hasPrefix("event:") || line.hasPrefix(":") || line.isEmpty {
                return
            } else if !line.hasPrefix("{") {
                return
            }
        }
        
        if target == .openai {
            if line.hasPrefix("data: ") {
                jsonLine = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if jsonLine == "[DONE]" || jsonLine.isEmpty {
                    return
                }
            } else if line.hasPrefix("event:") || line.hasPrefix(":") || line.isEmpty {
                return
            } else if !line.hasPrefix("{") {
                return
            }
        }
        
        guard !jsonLine.isEmpty,
              let data = jsonLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        switch target {
        case .ollama:
            await processOllamaStreamWithContinuation(json, continuation: continuation)
        case .lmstudio:
            await processLMStudioStreamWithContinuation(json, continuation: continuation)
        case .claude:
            await processClaudeStreamWithContinuation(json, continuation: continuation)
        case .openai:
            await processOpenAIStreamWithContinuation(json, continuation: continuation)
        }
    }
    
    private func processOllamaStreamWithContinuation(_ json: [String: Any], continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        if let message = json["message"] as? [String: Any],
           let content = message["content"] as? String {
            tempResponse += content
            await MainActor.run {
                currentResponse = tempResponse
            }
            continuation.yield(content)
        }
        
        if let done = json["done"] as? Bool, done {
            return
        }
    }
    
    private func processLMStudioStreamWithContinuation(_ json: [String: Any], continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let delta = firstChoice["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            tempResponse += content
            await MainActor.run {
                currentResponse = tempResponse
            }
            continuation.yield(content)
        }
        
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let finishReason = firstChoice["finish_reason"] as? String,
           finishReason == "stop" {
            return
        }
    }
    
    private func processClaudeStreamWithContinuation(_ json: [String: Any], continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        if let type = json["type"] as? String {
            switch type {
            case "content_block_delta":
                if let delta = json["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    tempResponse += text
                    await MainActor.run {
                        currentResponse = tempResponse
                    }
                    continuation.yield(text)
                }
            case "message_stop":
                return
            default:
                break
            }
        }
    }
    
    private func processOpenAIStreamWithContinuation(_ json: [String: Any], continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        // Chat Completions 스트림
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let delta = firstChoice["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            tempResponse += content
            await MainActor.run {
                currentResponse = tempResponse
            }
            continuation.yield(content)
            return
        }
        // Responses API 스트림
        if let type = json["type"] as? String {
            if type == "response.output_text.delta", let delta = json["delta"] as? String {
                tempResponse += delta
                await MainActor.run {
                    currentResponse = tempResponse
                }
                continuation.yield(delta)
                return
            }
            if type == "response.completed" {
                return
            }
        }
    }
    
    private func encodeImageToBase64(_ image: PlatformImage, compressionQuality: CGFloat = 0.8) -> String? {
        #if canImport(UIKit)
        let resizedImage = resizeImageIfNeeded(image, maxSize: 1024)
        guard let imageData = resizedImage.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        return imageData.base64EncodedString()
        #elseif canImport(AppKit)
        let resizedImage = resizeImageIfNeeded(image, maxSize: 1024)
        guard let cgImage = resizedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) else {
            return nil
        }
        return imageData.base64EncodedString()
        #endif
    }
    
    #if canImport(UIKit)
    private func resizeImageIfNeeded(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let maxDimension = max(size.width, size.height)
        
        if maxDimension <= maxSize {
            return image
        }
        
        let scaleFactor = maxSize / maxDimension
        let newWidth = size.width * scaleFactor
        let newHeight = size.height * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    #elseif canImport(AppKit)
    private func resizeImageIfNeeded(_ image: NSImage, maxSize: CGFloat) -> NSImage {
        let size = image.size
        let maxDimension = max(size.width, size.height)
        
        if maxDimension <= maxSize {
            return image
        }
        
        let scaleFactor = maxSize / maxDimension
        let newWidth = size.width * scaleFactor
        let newHeight = size.height * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        
        return resizedImage
    }
    #endif
    
    public func getBaseURL() -> URL {
        return baseURL
    }
    
    public func getPort() -> Int {
        return port
    }
    
    public func getTarget() -> LLMTarget {
        return target
    }
}
