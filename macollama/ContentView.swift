//
//  ContentView.swift
//  macollama
//
//  Created by BillyPark on 1/29/25.
//

import SwiftUI

struct ContentView: View {
    
    private enum ContentKeys {
        static let questionTag = "[Q]:"
        static let answerTag = "[A]:"
        static let separator = "----------------"
    }
    
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @State private var showingSettings = false
    @State private var models: [String] = []
    @State private var isLoadingModels = false
    @AppStorage("selectedModel") private var selectedModel: String?
    @AppStorage("selectedProvider") private var selectedProvider: LLMProvider = .ollama
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showCopyAlert = false
    
    @StateObject private var chatViewModel = ChatViewModel.shared
    
    private var toolbarContent: some View {
        HStack {
            HoverImageButton(imageName: "plus") {
                chatViewModel.startNewChat()
            }
            .accessibilityLabel(Text("New Chat"))
            HoverImageButton(imageName: "gearshape") {
                showingSettings = true
            }
            .accessibilityLabel(Text("Settings"))
        }
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .accessibilityLabel(Text("Sidebar"))
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        toolbarContent
                    }
                }
                .navigationTitle("")
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        ModelSelectionMenu(
                            selectedModel: $selectedModel,
                            selectedProvider: $selectedProvider,
                            models: $models,
                            isLoadingModels: $isLoadingModels,
                            onProviderChange: { await loadModels() },
                            onModelRefresh: { await loadModels() },
                            onCopyAllMessages: { copyAllMessages() }
                        )
                    }
                }
        } detail: {
            DetailView(selectedModel: $selectedModel, isLoadingModels: $isLoadingModels)
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            Task { await loadModels() }
        }) {
            SettingsView(isPresented: $showingSettings)
        }
        .task {
            await loadModels()
        }
        .alert("l_model_load_fail".localized, isPresented: $showingError) {
            Button("l_settings".localized) {
                showingSettings = true
            }
            Button("l_retry".localized) {
                Task {
                    await loadModels()
                }
            }
        } message: {
            Text("l_set_url".localized)
        }
        .overlay {
            if showCopyAlert {
                GeometryReader { geometry in
                    CenterAlertView(message: "l_copied".localized)
                        .accessibilityLabel(Text("Copied"))
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopyAlert)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    @MainActor
    func loadModels() async {
        isLoadingModels = true
        
        models = []
        selectedModel = nil
        
        // Check if current provider is available
        if !LLMProvider.availableProviders.contains(selectedProvider) {
            selectedProvider = LLMProvider.availableProviders.first ?? .ollama
        }
        
        do {
            let newModels = try await LLMService.shared.listModels()
            models = newModels
            
            if newModels.isEmpty {
                selectedModel = nil
            } else if let selected = selectedModel, !newModels.contains(selected) {
                selectedModel = newModels.first
            } else if selectedModel == nil {
                selectedModel = newModels.first
            }
        } catch {
            self.models = []
            self.selectedModel = nil
            await showError("l_error2".localized)
        }
        
        isLoadingModels = false
    }
    
    @MainActor
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func copyAllMessages() {
        let messages = ChatViewModel.shared.messages
        var content = ""
        
        for i in stride(from: 0, to: messages.count, by: 2) {
            if i + 1 < messages.count {
                content += """
                \(ContentKeys.questionTag)
                \(messages[i].content)
                
                \(ContentKeys.answerTag)
                \(messages[i + 1].content)
                
                \(ContentKeys.separator)
                
                """
            }
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        
        withAnimation {
            showCopyAlert = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopyAlert = false
            }
        }
    }
}

