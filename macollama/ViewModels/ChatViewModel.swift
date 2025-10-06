import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@MainActor
class ChatViewModel: ObservableObject {
    static let shared = ChatViewModel()
    
    @Published var messages: [ChatMessage] = []
    @Published var selectedImage: PlatformImage?
    @Published var messageText: String = ""
    @Published var chatId = UUID()
    @Published var shouldFocusTextField: Bool = false
    
    // UI에서 표시할 최대 메시지 수 (메모리 절약)
    private let maxDisplayMessages = 100
    
    private init() {}
    
    func startNewChat() {
        messages.removeAll()
        selectedImage = nil
        messageText = ""
        chatId = UUID()
        shouldFocusTextField = true
    }
    
    // 메시지 추가시 메모리 관리
    func addMessage(_ message: ChatMessage) {
        messages.append(message)
        
        // 메시지 수가 한계를 초과하면 오래된 메시지 제거
        if messages.count > maxDisplayMessages {
            let excess = messages.count - maxDisplayMessages
            messages.removeFirst(excess)
        }
    }
    
    // 안전한 메시지 업데이트 메서드
    func updateLastAssistantMessage(content: String, engine: String) {
        if let index = messages.lastIndex(where: { !$0.isUser }) {
            let existingMessage = messages[index]
            let updatedMessage = ChatMessage(
                id: existingMessage.id,
                content: content,
                isUser: false,
                timestamp: existingMessage.timestamp,
                image: nil,
                engine: engine
            )
            messages[index] = updatedMessage
        }
    }
    
    // 배치 업데이트를 위한 디바운스된 업데이트
    private var updateTask: Task<Void, Never>?
    
    func updateMessageContentDebounced(_ content: String, engine: String) {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            // 100ms 지연으로 UI 업데이트 배치 처리
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled, let self = self else { return }
            
            await MainActor.run {
                self.updateLastAssistantMessage(content: content, engine: engine)
            }
        }
    }
    
    @MainActor
    func loadChat(groupId: String) {
        do {
            let results = try DatabaseManager.shared.fetchQuestionsByGroupId(groupId)
            messages = []
            
            let dateFormatter = ISO8601DateFormatter()
            
            // 최근 메시지만 로드하여 메모리 절약
            let recentResults = Array(results.suffix(maxDisplayMessages / 2))
            
            for result in recentResults {
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
                
                // 답변에서 중복된 통계 정보 제거 (정규식 사용)
                var cleanAnswer = result.answer
                
                // 패턴: \n\n---\n [모델명] 숫자.숫자 tokens/sec 형태를 찾아서 중복 제거
                let pattern = "\\n\\n---\\n \\[.*?\\] \\d+\\.\\d+ tokens/sec"
                let regex = try? NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: cleanAnswer.utf16.count)
                let matches = regex?.matches(in: cleanAnswer, options: [], range: range) ?? []
                
                // 여러 개의 통계 정보가 있으면 마지막 것만 남기고 제거
                if matches.count > 1 {
                    // 뒤에서부터 제거 (인덱스가 변하지 않도록)
                    for i in (0..<matches.count - 1).reversed() {
                        let match = matches[i]
                        let matchRange = Range(match.range, in: cleanAnswer)!
                        cleanAnswer.removeSubrange(matchRange)
                    }
                }
                
                messages.append(ChatMessage(
                    id: result.id * 2 + 1,
                    content: cleanAnswer,
                    isUser: false,
                    timestamp: timestamp,
                    image: nil,
                    engine: result.engine
                ))
            }
            
            // 메시지 수가 한계를 초과하면 오래된 메시지 제거
            if messages.count > maxDisplayMessages {
                messages = Array(messages.suffix(maxDisplayMessages))
            }
            
            chatId = UUID(uuidString: groupId) ?? UUID()
        } catch {
            print("Failed to load chat: \(error)")
        }
    }
} 
