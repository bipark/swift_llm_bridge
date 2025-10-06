import SwiftUI

struct ModelSelectionMenu: View {
    @Binding var selectedModel: String?
    @Binding var selectedProvider: LLMProvider
    @Binding var models: [String]
    @Binding var isLoadingModels: Bool
    let onProviderChange: () async -> Void
    let onModelRefresh: () async -> Void
    let onCopyAllMessages: () -> Void
    
    @State private var availableProviders: [LLMProvider] = []
    
    private func updateAvailableProviders() {
        availableProviders = LLMProvider.allCases.filter { provider in
            switch provider {
            case .ollama:
                return UserDefaults.standard.bool(forKey: "showOllama")
            case .lmstudio:
                return UserDefaults.standard.bool(forKey: "showLMStudio")
            case .claude:
                return UserDefaults.standard.bool(forKey: "showClaude")
            case .openai:
                return UserDefaults.standard.bool(forKey: "showOpenAI")
            }
        }
        
        if !availableProviders.contains(selectedProvider),
           let firstProvider = availableProviders.first {
            selectedProvider = firstProvider
            LLMService.shared.refreshForProviderChange()
            Task {
                await onProviderChange()
            }
        }
    }
    
    var body: some View {
        HStack {
            // Provider Picker
            Picker("Provider", selection: $selectedProvider) {
                ForEach(availableProviders, id: \.self) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 160)
            .onChange(of: selectedProvider) { _, _ in
                LLMService.shared.refreshForProviderChange()
                Task { await onProviderChange() }
            }

            // Model Picker
            HStack(spacing: 4) {
                Picker("Model", selection: Binding(
                    get: { selectedModel ?? "" },
                    set: { selectedModel = $0.isEmpty ? nil : $0 }
                )) {
                    Text("l_select_model".localized).tag("")
                    ForEach(models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 260)
                .disabled(isLoadingModels)
                
                Button(action: { Task { await onModelRefresh() } }) {
                    if isLoadingModels {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isLoadingModels)
            }
            .frame(width: 300)

            Spacer()
            HoverImageButton(
                imageName: "document.on.document"
            ) {
                onCopyAllMessages()
            }
        }
        .onAppear {
            updateAvailableProviders()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            updateAvailableProviders()
        }
    }
}