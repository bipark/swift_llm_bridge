import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    private let onReloadModels: @Sendable () async -> Void
    @State private var serverAddress: String = UserDefaults.standard.string(forKey: "ollama_base_url") ?? "http://localhost:11434"
    @State private var lmStudioAddress: String = UserDefaults.standard.string(forKey: "lmStudioAddress") ?? "http://localhost:1234"
    @State private var claudeApiKey: String = ""
    @State private var openaiApiKey: String = ""
    @AppStorage("showOllama") private var showOllama: Bool = true
    @AppStorage("showLMStudio") private var showLMStudio: Bool = false
    @AppStorage("showClaude") private var showClaude: Bool = false
    @AppStorage("showOpenAI") private var showOpenAI: Bool = false
    @State private var llmInstruction: String = UserDefaults.standard.string(forKey: "llmInstruction") ?? "You are a helpful assistant."
    @State private var temperature: Double = UserDefaults.standard.double(forKey: "temperature")
    @State private var topP: Double = UserDefaults.standard.double(forKey: "topP") != 0 ? UserDefaults.standard.double(forKey: "topP") : 0.9
    @State private var topK: Double = UserDefaults.standard.double(forKey: "topK") != 0 ? UserDefaults.standard.double(forKey: "topK") : 40
    @State private var showingDeleteAlert = false
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?
    @State private var isTestingLMStudioConnection = false
    @State private var lmStudioConnectionTestResult: String?
    
    init(
        isPresented: Binding<Bool> = .constant(false),
        onReloadModels: @escaping @Sendable () async -> Void = {}
    ) {
        self._isPresented = isPresented
        self.onReloadModels = onReloadModels
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("LLM Servers")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Toggle(isOn: $showOllama) {
                                Text("Ollama Server")
                                    .foregroundStyle(.secondary)
                            }
                            .onChange(of: showOllama) {
                                Task {
                                    await onReloadModels()
                                }
                            }
                        }
                        HStack {
                            VStack {
                                TextEditor(text: $serverAddress)
                                    .font(.body)
                                    .padding(10)
                                    .foregroundColor(.primary)
                                    .background(Color(NSColor.textBackgroundColor))
                            }
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            
                            Button(action: {
                                testConnection()
                            }) {
                                if isTestingConnection {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Text("l_test_connection".localized)
                                        .font(.caption)
                                }
                            }
                            .disabled(isTestingConnection)
                            .buttonStyle(.bordered)
                        }
                        
                        if let result = connectionTestResult {
                            Text(result)
                                .font(.caption)
                                .foregroundColor(result.contains("l_connection_success".localized) ? .green : .red)
                                .padding(.top, 5)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Toggle(isOn: $showLMStudio) {
                                Text("LMStudio".localized)
                                    .foregroundStyle(.secondary)
                            }
                            .onChange(of: showLMStudio) {
                                Task {
                                    await onReloadModels()
                                }
                            }
                        }
                        HStack {
                            VStack {
                                TextEditor(text: $lmStudioAddress)
                                    .font(.body)
                                    .padding(10)
                                    .foregroundColor(.primary)
                                    .background(Color(NSColor.textBackgroundColor))
                            }
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            
                            Button(action: {
                                testLMStudioConnection()
                            }) {
                                if isTestingLMStudioConnection {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Text("l_test_connection".localized)
                                        .font(.caption)
                                }
                            }
                            .disabled(isTestingLMStudioConnection)
                            .buttonStyle(.bordered)
                        }
                        
                        if let result = lmStudioConnectionTestResult {
                            Text(result)
                                .font(.caption)
                                .foregroundColor(result.contains("l_connection_success".localized) ? .green : .red)
                                .padding(.top, 5)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Toggle(isOn: $showClaude) {
                                Text("Claude API Key")
                                    .foregroundStyle(.secondary)
                            }
                            .onChange(of: showClaude) {
                                Task {
                                    await onReloadModels()
                                }
                            }
                            .disabled(claudeApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        VStack {
                            TextEditor(text: $claudeApiKey)
                                .font(.body)
                                .padding(10)
                                .foregroundColor(.primary)
                                .background(Color(NSColor.textBackgroundColor))
                                .onChange(of: claudeApiKey) { _, newValue in
                                    let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if trimmedValue.isEmpty {
                                        showClaude = false
                                    } else {
                                        showClaude = true
                                    }
                                }
                        }
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Toggle(isOn: $showOpenAI) {
                                Text("OpenAI API Key")
                                    .foregroundStyle(.secondary)
                            }
                            .onChange(of: showOpenAI) {
                                Task {
                                    await onReloadModels()
                                }
                            }
                            .disabled(openaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        VStack {
                            TextEditor(text: $openaiApiKey)
                                .font(.body)
                                .padding(10)
                                .foregroundColor(.primary)
                                .background(Color(NSColor.textBackgroundColor))
                                .onChange(of: openaiApiKey) { _, newValue in
                                    let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if trimmedValue.isEmpty {
                                        showOpenAI = false
                                    } else {
                                        showOpenAI = true
                                    }
                                }
                        }
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                }

                Section(header: Text("LLM Settings")) {
                    
                    VStack(alignment: .leading) {
                        Text("l_llm_inst".localized)
                            .foregroundStyle(.secondary)
                        VStack {
                            TextEditor(text: $llmInstruction)
                                .font(.body)
                                .padding(10)
                                .frame(height: 100)
                                .foregroundColor(.primary)
                                .background(Color(NSColor.textBackgroundColor))
                        }
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("l_ai_model_instruction".localized)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading) {
                            Text("TEMPERATURE")
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("0.1")
                                    .font(.caption)
                                Slider(value: $temperature, in: 0.1...2.0, step: 0.1)
                                Text("2.0")
                                    .font(.caption)
                                Text(String(format: "%.1f", temperature))
                                    .font(.caption)
                                    .frame(width: 30)
                            }
                            Text("l_temperature_desc".localized)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("TOP P")
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("0.1")
                                    .font(.caption)
                                Slider(value: $topP, in: 0.1...1.0, step: 0.1)
                                Text("1.0")
                                    .font(.caption)
                                Text(String(format: "%.1f", topP))
                                    .font(.caption)
                                    .frame(width: 30)
                            }
                            Text("l_top_p_desc".localized)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("TOP K")
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("1")
                                    .font(.caption)
                                Slider(value: $topK, in: 1...100, step: 1)
                                Text("100")
                                    .font(.caption)
                                Text(String(format: "%.0f", topK))
                                    .font(.caption)
                                    .frame(width: 30)
                            }
                            Text("l_top_k_desc".localized)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Link("l_ollama_method".localized, destination: URL(string: "http://practical.kr/?p=828")!)
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("l_version".localized)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.gray)
                    }
                }
                
                Section {
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Label("l_delete_all".localized, systemImage: "trash")
                                .foregroundColor(.red)
                                .padding(5)
                            Spacer()
                        }
                    }
                }
                

            }
            .formStyle(.grouped)
            .navigationTitle("l_settings".localized)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("l_close".localized) {
                        saveSettings()
                        isPresented = false
                        Task {
                            await onReloadModels()
                        }
                    }
                }
            }
        }
        .frame(width: 600, height: 540)
        .fixedSize()
        .alert("l_delete_all".localized, isPresented: $showingDeleteAlert) {
            Button("l_cancel".localized, role: .cancel) { }
            Button("l_delete", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("l_delete_all_question".localized)
        }
        .onAppear {
            loadAPIKeys()
        }
    }

    private func loadAPIKeys() {
        do {
            claudeApiKey = try SecureConfigurationManager.shared.getAPIKey(for: .claude) ?? ""
            openaiApiKey = try SecureConfigurationManager.shared.getAPIKey(for: .openai) ?? ""
        } catch {
            #if DEBUG
            print("Failed to load API keys from Keychain: \(error)")
            #endif
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(serverAddress, forKey: "ollama_base_url")
        UserDefaults.standard.set(lmStudioAddress, forKey: "lmStudioAddress")
        UserDefaults.standard.set(llmInstruction, forKey: "llmInstruction")
        UserDefaults.standard.set(temperature, forKey: "temperature")
        UserDefaults.standard.set(topP, forKey: "topP")
        UserDefaults.standard.set(topK, forKey: "topK")
        UserDefaults.standard.synchronize()

        // Save API keys to Keychain
        do {
            if !claudeApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try SecureConfigurationManager.shared.saveAPIKey(claudeApiKey, for: .claude)
            }
            if !openaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try SecureConfigurationManager.shared.saveAPIKey(openaiApiKey, for: .openai)
            }
        } catch {
            #if DEBUG
            print("Failed to save API keys to Keychain: \(error)")
            #endif
        }
    }
    
    private func deleteAllData() {
        Task {
            do {
                try DatabaseManager.shared.deleteAllData()
                await MainActor.run {
                    SidebarViewModel.shared.refresh()
                    ChatViewModel.shared.startNewChat()
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    ChatViewModel.shared.error = ChatError.databaseError(error)
                    ChatViewModel.shared.showingError = true
                }
            }
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil
        
        Task {
            guard let url = URL(string: serverAddress) else {
                connectionTestResult = "l_connection_fail".localized
                isTestingConnection = false
                return
            }

            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.timeoutInterval = 10.0
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        connectionTestResult = "l_connection_success".localized
                    } else {
                        connectionTestResult = "l_connection_fail_status".localized
                    }
                }
            } catch {
                connectionTestResult = "l_connection_fail".localized
            }
            
            isTestingConnection = false
        }
    }
    
    private func testLMStudioConnection() {
        isTestingLMStudioConnection = true
        lmStudioConnectionTestResult = nil
        
        Task {
            guard let url = URL(string: lmStudioAddress) else {
                lmStudioConnectionTestResult = "l_connection_fail".localized
                isTestingLMStudioConnection = false
                return
            }

            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.timeoutInterval = 10.0
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        lmStudioConnectionTestResult = "l_connection_success".localized
                    } else {
                        lmStudioConnectionTestResult = "l_connection_fail_status".localized
                    }
                }
            } catch {
                lmStudioConnectionTestResult = "l_connection_fail".localized
            }
            
            isTestingLMStudioConnection = false
        }
    }
} 

