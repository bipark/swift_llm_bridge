import SwiftUI
import SwiftUI
import MarkdownUI

struct DetailView: View {
    @Binding var selectedModel: String?
    @Binding var isLoadingModels: Bool
    @ObservedObject private var viewModel = ChatViewModel.shared
    @Namespace private var bottomID
    @State private var isGenerating = false  
    @State private var responseStartTime: Date? 
    @State private var tokenCount: Int = 0 
    
    var body: some View {
        VStack(spacing: 0) {
            
            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if #available(macOS 15, *) {
                            GlassEffectContainer(spacing: 24) {
                                LazyVStack(spacing: 20) {
                                    ForEach(viewModel.messages) { message in
                                        VStack(alignment: HorizontalAlignment.trailing, spacing: 4) {
                                            MessageBubble(message: message)
                                        }
                                        .id(message.id)
                                    }
                                    Color.clear
                                        .frame(height: 1)
                                        .id(bottomID)
                                }
                            }
                        } else {
                            LazyVStack(spacing: 20) {
                                ForEach(viewModel.messages) { message in
                                    VStack(alignment: HorizontalAlignment.trailing, spacing: 4) {
                                        MessageBubble(message: message)
                                    }
                                    .id(message.id)
                                }
                                Color.clear
                                    .frame(height: 1)
                                    .id(bottomID)
                            }
                        }
                    }
                    .padding()
                }
                .onReceive(viewModel.$messages) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            MessageInputView(
                viewModel: viewModel,
                selectedModel: $selectedModel,
                isGenerating: $isGenerating,
                isLoadingModels: $isLoadingModels,
                onSendMessage: { Task { await sendMessage() } },
                onCancelGeneration: {
                    LLMService.shared.cancelGeneration()
                    isGenerating = false
                }
            )
            .padding(8)
            .modifier(GlassEffectModifier())
            .background(
                Group {
                    if #available(macOS 15, *) { Color.clear } else { Color.gray.opacity(0.08) }
                }
            )
            .padding([Edge.Set.leading, Edge.Set.trailing])
            .padding(Edge.Set.bottom, 8)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }
    
    private func sendMessage() async {
        guard let selectedModel = selectedModel,
              !viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let currentText = viewModel.messageText
        let currentImage = viewModel.selectedImage
        
        // Clear input and set generating state first
        viewModel.messageText = ""
        viewModel.selectedImage = nil
        isGenerating = true
        responseStartTime = Date()
        tokenCount = 0

        // Add user message
        let userMessage = ChatMessage(
            id: viewModel.messages.count * 2,
            content: currentText,
            isUser: true,
            timestamp: Date(),
            image: currentImage,
            engine: selectedModel
        )
        viewModel.addMessage(userMessage)
        
        let waitingMessage = ChatMessage(
            id: viewModel.messages.count * 2 + 1,
            content: "...",
            isUser: false,
            timestamp: Date(),
            image: nil,
            engine: selectedModel
        )
        viewModel.addMessage(waitingMessage)
        
        Task {
            do {
                var fullResponse = ""
                let stream = try await LLMService.shared.generateResponse(
                    prompt: currentText,
                    image: currentImage,
                    model: selectedModel
                )
                
                for try await response in stream {
                    fullResponse += response
                    tokenCount += response.count 
                    
                    // 안전한 메시지 업데이트 (디바운스 적용)
                    viewModel.updateMessageContentDebounced(fullResponse, engine: selectedModel)
                }
                
                var statsMessage = ""
                if let startTime = responseStartTime {
                    let elapsedTime = Date().timeIntervalSince(startTime)
                    let tokensPerSecond = Double(tokenCount) / elapsedTime
                    statsMessage = "\n\n---\n [\(selectedModel)] \(String(format: "%.1f", tokensPerSecond)) tokens/sec"
                    
                    // 기존 통계 정보가 있다면 제거
                    var cleanResponse = fullResponse
                    if let separatorRange = fullResponse.range(of: "\n\n---\n") {
                        cleanResponse = String(fullResponse[..<separatorRange.lowerBound])
                    }
                    
                    if let index = viewModel.messages.lastIndex(where: { !$0.isUser }) {
                        viewModel.updateLastAssistantMessage(
                            content: cleanResponse + statsMessage,
                            engine: selectedModel
                        )
                    }
                    
                    // 데이터베이스에도 깨끗한 응답 + 통계 저장
                    fullResponse = cleanResponse
                }
            }
            
            var statsMessage = ""
            if let startTime = responseStartTime {
                let elapsedTime = Date().timeIntervalSince(startTime)
                let tokensPerSecond = Double(tokenCount) / elapsedTime
                statsMessage = "\n\n---\n [\(selectedModel)] \(String(format: "%.1f", tokensPerSecond)) tokens/sec"
                
                if let index = viewModel.messages.lastIndex(where: { !$0.isUser }) {
                    viewModel.updateLastAssistantMessage(
                        content: "\(error.localizedDescription)",
                        engine: selectedModel
                    )
                }
            }
            
            try DatabaseManager.shared.insert(
                groupId: viewModel.chatId.uuidString,
                instruction: UserDefaults.standard.string(forKey: "llmInstruction") ?? "",
                question: currentText,
                answer: fullResponse + statsMessage,
                image: currentImage,
                engine: selectedModel
            )
            
            SidebarViewModel.shared.refresh()
            
        } catch {
            if let index = viewModel.messages.lastIndex(where: { !$0.isUser }) {
                let errorMessage = ChatMessage(
                    id: viewModel.messages[index].id,
                    content: "\(error.localizedDescription)",
                    isUser: false,
                    timestamp: Date(),
                    image: nil,
                    engine: selectedModel
                )
                viewModel.messages[index] = errorMessage
            }
        }
        
        isGenerating = false
        responseStartTime = nil
        tokenCount = 0
    }
}

// MARK: - Glass Effect Modifier
struct GlassEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            content
        }
    }
}
