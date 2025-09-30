import SwiftUI
import MarkdownUI

struct DetailView: View {
    @Binding var selectedModel: String?
    @Binding var isLoadingModels: Bool
    @StateObject private var viewModel = ChatViewModel.shared
    @Namespace private var bottomID
    @State private var isGenerating = false  
    @State private var responseStartTime: Date? 
    @State private var tokenCount: Int = 0 
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(viewModel.messages) { message in
                            VStack(alignment: .trailing, spacing: 4) {
                                MessageBubble(message: message)
                            }
                            .id(message.id)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onChange(of: viewModel.messages.last?.content) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onReceive(viewModel.$messages) { _ in
                    if isGenerating {
                        withAnimation(.easeOut(duration: 0.1)) {
                            scrollToBottom(proxy: proxy)
                        }
                    }
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
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        proxy.scrollTo(bottomID, anchor: .bottom)
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
        viewModel.messages.append(userMessage)

        // Add waiting message
        let waitingMessage = ChatMessage(
            id: viewModel.messages.count * 2 + 1,
            content: "...",
            isUser: false,
            timestamp: Date(),
            image: nil,
            engine: selectedModel
        )
        viewModel.messages.append(waitingMessage)
        
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
                if let index = viewModel.messages.lastIndex(where: { !$0.isUser }) {
                    let updatedMessage = ChatMessage(
                        id: viewModel.messages[index].id,
                        content: fullResponse,
                        isUser: false,
                        timestamp: viewModel.messages[index].timestamp,
                        image: nil,
                        engine: selectedModel
                    )
                    await MainActor.run {
                        viewModel.messages[index] = updatedMessage
                    }
                }
            }
            
            var statsMessage = ""
            if let startTime = responseStartTime {
                let elapsedTime = Date().timeIntervalSince(startTime)
                let tokensPerSecond = Double(tokenCount) / elapsedTime
                statsMessage = "\n\n---\n [\(selectedModel)] \(String(format: "%.1f", tokensPerSecond)) tokens/sec"
                
                if let index = viewModel.messages.lastIndex(where: { !$0.isUser }) {
                    let updatedMessage = ChatMessage(
                        id: viewModel.messages[index].id,
                        content: fullResponse + statsMessage,
                        isUser: false,
                        timestamp: viewModel.messages[index].timestamp,
                        image: nil,
                        engine: selectedModel
                    )
                    await MainActor.run {
                        viewModel.messages[index] = updatedMessage
                    }
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

