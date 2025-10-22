//
//  ChatDetailView.swift
//  myollama
//
//  Created by rtlink on 6/12/25.
//

import SwiftUI

struct ChatDetailView: View {
    @StateObject private var chatViewModel = ChatViewModel.shared
    @State private var selectedModel: String?
    @State private var isLoadingModels = false
    @State private var isGenerating = false
    @State private var models: [String] = []
    @AppStorage("selectedLLMProvider") private var selectedProvider: LLMProvider = .ollama
    @State private var responseStartTime: Date?
    @State private var tokenCount: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(chatViewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onTapGesture {
                    hideKeyboard()
                }
                .onReceive(chatViewModel.$messages) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            MessageInputView(
                viewModel: chatViewModel,
                selectedModel: $selectedModel,
                isGenerating: $isGenerating,
                onSendMessage: sendMessage,
                onCancelGeneration: {
                    LLMService.shared.cancelGeneration()
                    isGenerating = false
                }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    ForEach(LLMProvider.availableProviders, id: \.self) { provider in
                        Button(action: {
                            selectedProvider = provider
                        }) {
                            HStack {
                                Text(provider.displayName)
                                if selectedProvider == provider {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label {
                        Text(selectedProvider.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .fixedSize(horizontal: true, vertical: false)
                    } icon: {
                        Image(systemName: "server.rack")
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
            
            ToolbarItem(placement: .principal) {
                Menu {
                    if !models.isEmpty {
                        ForEach(models, id: \.self) { model in
                            Button(action: {
                                selectedModel = model
                            }) {
                                HStack {
                                    Text(model)
                                    if selectedModel == model {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button("l_refresh_models".localized) {
                            Task {
                                await loadModels()
                            }
                        }
                    } else {
                        Button("l_no_models".localized) {
                            Task {
                                await loadModels()
                            }
                        }
                        .disabled(true)
                        
                        Button("l_refresh_models".localized) {
                            Task {
                                await loadModels()
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedProvider.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(2)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(selectedModel ?? "l_model_select".localized)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 200)
                }
            }
        }
        .task {
            await loadModels()
        }
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: Notification.Name("ReloadModelNotification"),
                object: nil,
                queue: .main
            ) { _ in
                Task{
                    await loadModels()
                }
            }
            
            // Sync with ChatViewModel when view appears
            selectedProvider = chatViewModel.chatProvider
            selectedModel = chatViewModel.chatModel
        }
        .onChange(of: chatViewModel.chatId) { _, _ in
            // When chat changes, update our local provider/model from ChatViewModel
            selectedProvider = chatViewModel.chatProvider
            selectedModel = chatViewModel.chatModel
        }
        .onChange(of: selectedProvider) { _, newProvider in
            // When user changes provider, update ChatViewModel and save
            chatViewModel.chatProvider = newProvider
            chatViewModel.saveProviderAndModel()
            Task {
                await loadModels()
            }
        }
        .onChange(of: selectedModel) { _, newModel in
            // When user changes model, update ChatViewModel and save
            chatViewModel.chatModel = newModel
            chatViewModel.saveProviderAndModel()
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = chatViewModel.messages.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    @MainActor
    func loadModels() async {
        isLoadingModels = true
        models = []
        // Don't reset selectedModel here - preserve chat-specific selection
        
        // Check if current provider is available
        if !LLMProvider.availableProviders.contains(selectedProvider) {
            selectedProvider = LLMProvider.availableProviders.first ?? .ollama
        }
        
        do {
            let newModels = try await LLMService.shared.listModels()
            models = newModels
            
            if newModels.isEmpty {
                selectedModel = nil
            } else {
                // Use chat-specific model if available, otherwise use first model
                let chatModel = chatViewModel.chatModel
                if let chatModel = chatModel, newModels.contains(chatModel) {
                    selectedModel = chatModel
                } else {
                    selectedModel = newModels.first
                    chatViewModel.chatModel = newModels.first
                    chatViewModel.saveProviderAndModel()
                }
            }
        } catch {
            models = []
            selectedModel = nil
        }
        
        isLoadingModels = false
    }
    
    private func sendMessage() {
        guard let selectedModel = selectedModel,
              (!chatViewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatViewModel.selectedImage != nil) else {
            return
        }
        
        let currentText = chatViewModel.messageText
        let currentImage = chatViewModel.selectedImage
        
        chatViewModel.messageText = ""
        chatViewModel.selectedImage = nil
        isGenerating = true
        
        responseStartTime = Date()
        tokenCount = 0
        
        let userMessage = ChatMessage(
            id: chatViewModel.messages.count * 2,
            content: currentText,
            isUser: true,
            timestamp: Date(),
            image: currentImage,
            engine: selectedModel
        )
        chatViewModel.messages.append(userMessage)
        
        let waitingMessage = ChatMessage(
            id: chatViewModel.messages.count * 2 + 1,
            content: "...",
            isUser: false,
            timestamp: Date(),
            image: nil,
            engine: selectedModel
        )
        chatViewModel.messages.append(waitingMessage)
        
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
                    
                    await MainActor.run {
                        if let index = chatViewModel.messages.lastIndex(where: { !$0.isUser }) {
                            let updatedMessage = ChatMessage(
                                id: chatViewModel.messages[index].id,
                                content: fullResponse,
                                isUser: false,
                                timestamp: chatViewModel.messages[index].timestamp,
                                image: nil,
                                engine: selectedModel
                            )
                            chatViewModel.messages[index] = updatedMessage
                        }
                    }
                }
                
                try DatabaseManager.shared.insert(
                    groupId: chatViewModel.chatId.uuidString,
                    instruction: UserDefaults.standard.string(forKey: "llmInstruction") ?? "",
                    question: currentText,
                    answer: fullResponse,
                    image: currentImage,
                    engine: selectedModel,
                    provider: selectedProvider.rawValue,
                    model: selectedModel
                )
                
                // Refresh sidebar
                await SidebarViewModel.shared.refresh()
                
            } catch {
                if let index = chatViewModel.messages.lastIndex(where: { !$0.isUser }) {
                    let errorMessage = ChatMessage(
                        id: chatViewModel.messages[index].id,
                        content: "\(error.localizedDescription)",
                        isUser: false,
                        timestamp: Date(),
                        image: nil,
                        engine: selectedModel
                    )
                    chatViewModel.messages[index] = errorMessage
                }
            }
            
            isGenerating = false
            responseStartTime = nil
            tokenCount = 0
        }
    }
} 

