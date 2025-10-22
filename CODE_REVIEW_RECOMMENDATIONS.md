# Swift LLM Bridge - Code Review & Improvement Recommendations

## Executive Summary
This document provides a comprehensive code review and improvement recommendations for the Swift LLM Bridge project. The analysis covers architecture, code quality, security, performance, and maintainability.

**Overall Assessment**: The codebase is well-structured with good separation of concerns using MVVM architecture. However, there are opportunities for significant improvements in error handling, testing, code duplication, and modern Swift practices.

---

## 1. Architecture & Design Patterns

### 1.1 Dependency Injection
**Issue**: Heavy reliance on singletons and `UserDefaults` makes testing difficult and creates tight coupling.

**Current Code** (swift_llm_bridge.swift:113-116):
```swift
self.temperature = UserDefaults.standard.double(forKey: "temperature")
self.topP = UserDefaults.standard.double(forKey: "topP") != 0 ? UserDefaults.standard.double(forKey: "topP") : 0.9
self.topK = UserDefaults.standard.double(forKey: "topK") != 0 ? UserDefaults.standard.double(forKey: "topK") : 40
```

**Recommendation**: Implement a configuration protocol and inject dependencies.

**Proposed Solution**:
```swift
// Create a configuration protocol
protocol LLMConfiguration {
    var temperature: Double { get }
    var topP: Double { get }
    var topK: Double { get }
    var baseURL: String { get }
    // ... other config properties
}

// UserDefaults implementation
struct UserDefaultsConfiguration: LLMConfiguration {
    var temperature: Double {
        UserDefaults.standard.double(forKey: "temperature")
    }
    var topP: Double {
        UserDefaults.standard.double(forKey: "topP") != 0
            ? UserDefaults.standard.double(forKey: "topP")
            : 0.9
    }
    // ... implement other properties
}

// Update LLMBridge to accept configuration
public init(configuration: LLMConfiguration, target: LLMTarget = .ollama, apiKey: String? = nil) {
    // Use configuration instead of directly accessing UserDefaults
}
```

**Benefits**:
- Easier testing with mock configurations
- Reduced coupling to UserDefaults
- Better separation of concerns
- More flexible for different configuration sources

---

### 1.2 Repository Pattern for Database Access
**Issue**: Direct database access throughout the codebase violates separation of concerns.

**Current Code** (MainChatView.swift:381-390):
```swift
try DatabaseManager.shared.insert(
    groupId: viewModel.chatId.uuidString,
    instruction: UserDefaults.standard.string(forKey: "llmInstruction") ?? "",
    question: currentText,
    answer: fullResponse + statsMessage,
    image: currentImage,
    engine: selectedModel,
    provider: viewModel.chatProvider.rawValue,
    model: viewModel.chatModel ?? selectedModel
)
```

**Recommendation**: Create a repository layer to abstract database operations.

**Proposed Solution**:
```swift
protocol ChatRepository {
    func saveMessage(groupId: String, question: String, answer: String, image: PlatformImage?, metadata: ChatMetadata) async throws
    func fetchChatHistory(groupId: String) async throws -> [ChatMessage]
    func deleteChat(groupId: String) async throws
    func searchChats(keyword: String) async throws -> [ChatTitle]
}

class SQLiteChatRepository: ChatRepository {
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    func saveMessage(groupId: String, question: String, answer: String, image: PlatformImage?, metadata: ChatMetadata) async throws {
        try databaseManager.insert(
            groupId: groupId,
            instruction: metadata.instruction,
            question: question,
            answer: answer,
            image: image,
            engine: metadata.engine,
            provider: metadata.provider,
            model: metadata.model
        )
    }
    // ... implement other methods
}
```

**Benefits**:
- Easier to swap database implementations
- Better testability
- Clear separation between business logic and data access
- Async/await support built-in

---

## 2. Error Handling

### 2.1 Silent Error Swallowing
**Critical Issue**: Multiple locations silently catch and ignore errors.

**Current Code** (ChatViewModel.swift:124-125):
```swift
} catch {
}
```

**Locations**:
- ChatViewModel.swift:64-66, 124-125, 126-127
- DatabaseManager.swift:133 (prints but doesn't propagate)
- SettingsView.swift:368 (removed print but no handling)

**Recommendation**: Implement proper error handling with user feedback.

**Proposed Solution**:
```swift
// 1. Define domain-specific errors
enum ChatError: LocalizedError {
    case loadFailed(String)
    case saveFailed(String)
    case databaseError(Error)

    var errorDescription: String? {
        switch self {
        case .loadFailed(let groupId):
            return "Failed to load chat: \(groupId)"
        case .saveFailed(let reason):
            return "Failed to save: \(reason)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}

// 2. Add error state to ViewModels
@Published var error: Error?
@Published var showingError = false

// 3. Properly handle errors
func loadChat(groupId: String) {
    do {
        let results = try DatabaseManager.shared.fetchQuestionsByGroupId(groupId)
        // ... process results
    } catch {
        self.error = ChatError.loadFailed(groupId)
        self.showingError = true
        Logger.shared.error("Failed to load chat", error: error)
    }
}

// 4. Show user-friendly errors in UI
.alert("Error", isPresented: $viewModel.showingError, presenting: viewModel.error) { _ in
    Button("OK") { }
} message: { error in
    Text(error.localizedDescription)
}
```

---

### 2.2 Force Unwrapping and Crash-Prone Code
**Issue**: Fatal errors and force unwraps can crash the app.

**Current Code** (swift_llm_bridge.swift:93-100):
```swift
guard let url = URL(string: "https://api.anthropic.com") else {
    fatalError("Invalid Claude API URL")
}
```

**Recommendation**: Use proper error handling instead of `fatalError`.

**Proposed Solution**:
```swift
enum LLMBridgeError: LocalizedError {
    case invalidURL(String)
    case configurationError(String)
}

public init(baseURL: String = "http://localhost", port: Int = 11434, target: LLMTarget = .ollama, apiKey: String? = nil) throws {
    if target == .claude {
        guard let url = URL(string: "https://api.anthropic.com") else {
            throw LLMBridgeError.invalidURL("https://api.anthropic.com")
        }
        self.baseURL = url
        self.port = 443
    }
    // ... rest of initialization
}
```

---

## 3. Code Duplication

### 3.1 SSE Parsing Logic Duplication
**Issue**: SSE (Server-Sent Events) parsing code is duplicated across multiple methods.

**Locations**:
- swift_llm_bridge.swift:776-814 (processStreamLine)
- swift_llm_bridge.swift:934-974 (processStreamLineWithContinuation)

**Impact**: Over 80 lines of duplicated code

**Recommendation**: Extract SSE parsing into a reusable function.

**Proposed Solution**:
```swift
private struct SSEParser {
    static func parseDataLine(_ line: String, target: LLMTarget) -> String? {
        var jsonLine = line

        // Common SSE parsing logic for all targets
        if target == .lmstudio || target == .claude || target == .openai {
            if line.hasPrefix("data: ") {
                jsonLine = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                if jsonLine == "[DONE]" || jsonLine.isEmpty {
                    return nil
                }
            } else if line.hasPrefix("event:") || line.hasPrefix(":") || line.isEmpty {
                return nil
            } else if !line.hasPrefix("{") {
                return nil
            }
        }

        return jsonLine.isEmpty ? nil : jsonLine
    }
}

// Usage:
private func processStreamLine(_ line: String) async {
    guard let jsonLine = SSEParser.parseDataLine(line, target: target),
          let data = jsonLine.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return
    }
    // ... process JSON
}
```

---

### 3.2 Request Creation Duplication
**Issue**: Similar request creation logic for different providers.

**Current Code**: createOllamaChatRequest, createLMStudioChatRequest, createOpenAIChatRequest (lines 479-632)

**Recommendation**: Use a protocol-oriented approach with provider-specific implementations.

**Proposed Solution**:
```swift
protocol LLMRequestBuilder {
    func buildChatRequest(
        messages: [Message],
        content: String,
        image: PlatformImage?,
        model: String,
        parameters: ModelParameters
    ) -> [String: Any]
}

struct ModelParameters {
    let temperature: Double
    let topP: Double
    let topK: Double
    let maxTokens: Int
    let stream: Bool
}

struct OllamaRequestBuilder: LLMRequestBuilder {
    func buildChatRequest(messages: [Message], content: String, image: PlatformImage?, model: String, parameters: ModelParameters) -> [String: Any] {
        // Ollama-specific implementation
    }
}

// In LLMBridge, use a factory:
private func getRequestBuilder(for target: LLMTarget) -> LLMRequestBuilder {
    switch target {
    case .ollama: return OllamaRequestBuilder()
    case .lmstudio: return LMStudioRequestBuilder()
    case .claude: return ClaudeRequestBuilder()
    case .openai: return OpenAIRequestBuilder()
    }
}
```

---

## 4. SwiftUI Best Practices

### 4.1 Duplicate onChange Handlers
**Issue**: Multiple onChange handlers for the same properties create redundant code.

**Current Code** (MainChatView.swift:29-40, 56-88):
```swift
.onChange(of: selectedProvider) { _, newProvider in
    handleProviderChange(newProvider)
}
.onChange(of: selectedModel) { _, newModel in
    handleModelChange(newModel)
}
// ... then again later:
.onChange(of: selectedProvider) { _, newProvider in
    if newProvider != viewModel.chatProvider {
        viewModel.updateProviderAndModel(newProvider, selectedModel)
    }
}
```

**Recommendation**: Consolidate onChange handlers and use Combine for reactive updates.

**Proposed Solution**:
```swift
struct MainChatView: View {
    @StateObject private var coordinator = ChatCoordinator()

    var body: some View {
        mainContent
            .onAppear {
                coordinator.setup(selectedProvider: selectedProvider, selectedModel: selectedModel)
            }
    }
}

@MainActor
class ChatCoordinator: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    func setup(selectedProvider: LLMProvider, selectedModel: String?) {
        // Single source of truth for state synchronization
        $selectedProvider
            .combineLatest($selectedModel)
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .sink { [weak self] provider, model in
                self?.updateConfiguration(provider: provider, model: model)
            }
            .store(in: &cancellables)
    }
}
```

---

### 4.2 ScrollView Performance
**Issue**: Multiple onChange handlers on ScrollView can cause performance issues.

**Current Code** (MainChatView.swift:116-143):
```swift
.onChange(of: viewModel.messages.count) { _, _ in
    withAnimation(.easeOut(duration: 0.3)) {
        proxy.scrollTo(bottomID, anchor: .bottom)
    }
}
.onChange(of: viewModel.messages.last?.content) { _, _ in
    // More scrolling logic
}
```

**Recommendation**: Use a single, debounced scroll trigger.

**Proposed Solution**:
```swift
@State private var scrollTrigger = UUID()

var body: some View {
    ScrollViewReader { proxy in
        ScrollView {
            messagesContent
        }
        .onChange(of: scrollTrigger) { _, _ in
            withAnimation(scrollAnimation) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }
}

// In ViewModel
@Published private(set) var scrollTrigger = UUID()

func appendMessage(_ message: ChatMessage) {
    messages.append(message)
    // Debounce scroll updates
    scrollTrigger = UUID()
}
```

---

## 5. Database & Persistence

### 5.1 Commented Code Accumulation
**Issue**: Large blocks of commented-out code reduce readability.

**Current Code** (DatabaseManager.swift:65-92, 95-108):
```swift
// Add title column to existing databases if it doesn't exist
//        let addTitleColumnQuery = "ALTER TABLE questions ADD COLUMN title TEXT;"
//        var alterStatement: OpaquePointer?
//        if sqlite3_prepare_v2(db, addTitleColumnQuery, -1, &alterStatement, nil) == SQLITE_OK {
//            sqlite3_step(alterStatement) // This will fail if column already exists, which is fine
//        }
//        sqlite3_finalize(alterStatement)
```

**Recommendation**: Remove commented code or move to database migration system.

**Proposed Solution**:
```swift
// Create a migration system
struct DatabaseMigration {
    let version: Int
    let description: String
    let migration: (OpaquePointer?) -> Bool
}

class DatabaseMigrationManager {
    private let migrations: [DatabaseMigration] = [
        DatabaseMigration(version: 1, description: "Add title column") { db in
            // Run migration
            return true
        },
        DatabaseMigration(version: 2, description: "Add provider column") { db in
            // Run migration
            return true
        }
    ]

    func runMigrations(on db: OpaquePointer?) {
        let currentVersion = getDatabaseVersion(db)
        for migration in migrations where migration.version > currentVersion {
            if migration.migration(db) {
                updateDatabaseVersion(db, to: migration.version)
            }
        }
    }
}
```

---

### 5.2 Debug Code in Production
**Issue**: Debug methods and logging statements should not be in production code.

**Current Code** (DatabaseManager.swift:557-662):
```swift
// DEBUG: Helper function to inspect all data in the database
func debugInspectDatabase() {
    print("=== DEBUG: Database Inspection ===")
    // ... 100+ lines of debug code
}
```

**Recommendation**: Use conditional compilation and a logging framework.

**Proposed Solution**:
```swift
// Create a Logger utility
struct Logger {
    enum Level {
        case debug, info, warning, error
    }

    static func log(_ message: String, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print("[\(level)] [\(fileName):\(line)] \(function) - \(message)")
        #endif
    }
}

// Use in code:
#if DEBUG
extension DatabaseManager {
    func inspectDatabase() {
        Logger.log("Database Inspection", level: .debug)
        // ... inspection code
    }
}
#endif
```

---

### 5.3 SQL Injection Risk
**Issue**: While using prepared statements (good!), the code could benefit from stronger type safety.

**Recommendation**: Consider using a Swift ORM like GRDB or create typed queries.

**Proposed Solution**:
```swift
// Using GRDB (recommended)
struct Question: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var groupId: String
    var instruction: String?
    var question: String
    var answer: String
    var image: String?
    var created: Date
    var engine: String
    var title: String?
    var provider: String?
    var model: String?
}

// Usage:
func insert(question: Question) throws {
    try dbQueue.write { db in
        try question.insert(db)
    }
}

func fetchQuestions(groupId: String) throws -> [Question] {
    try dbQueue.read { db in
        try Question
            .filter(Column("groupId") == groupId)
            .order(Column("id").asc)
            .fetchAll(db)
    }
}
```

---

## 6. Networking & API

### 6.1 Hardcoded Configuration
**Issue**: API endpoints, versions, and timeouts are hardcoded throughout the code.

**Current Code** (swift_llm_bridge.swift:139, 229, 322):
```swift
request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
request.addValue("responses-2024-12-17", forHTTPHeaderField: "OpenAI-Beta")
```

**Recommendation**: Centralize configuration in a constants file.

**Proposed Solution**:
```swift
struct APIConfiguration {
    struct Claude {
        static let apiVersion = "2023-06-01"
        static let baseURL = "https://api.anthropic.com"
        static let timeout: TimeInterval = 300.0
    }

    struct OpenAI {
        static let baseURL = "https://api.openai.com"
        static let betaHeader = "responses-2024-12-17"
        static let timeout: TimeInterval = 300.0
    }

    struct Ollama {
        static let defaultHost = "localhost"
        static let defaultPort = 11434
    }
}

// Usage:
request.addValue(APIConfiguration.Claude.apiVersion, forHTTPHeaderField: "anthropic-version")
```

---

### 6.2 Error Response Parsing
**Issue**: Error parsing is inconsistent and could be more robust.

**Current Code** (swift_llm_bridge.swift:724-734):
```swift
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
```

**Recommendation**: Create typed error responses for each provider.

**Proposed Solution**:
```swift
protocol APIErrorResponse: Codable {
    var message: String { get }
    var code: String? { get }
}

struct ClaudeErrorResponse: APIErrorResponse {
    let error: ErrorDetail

    var message: String { error.message }
    var code: String? { error.type }

    struct ErrorDetail: Codable {
        let type: String
        let message: String
    }
}

struct OpenAIErrorResponse: APIErrorResponse {
    let error: ErrorDetail

    var message: String { error.message }
    var code: String? { error.code }

    struct ErrorDetail: Codable {
        let message: String
        let type: String
        let code: String?
    }
}

func parseError<T: APIErrorResponse>(_ data: Data, as type: T.Type) -> String {
    guard let errorResponse = try? JSONDecoder().decode(type, from: data) else {
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
    return errorResponse.message
}
```

---

## 7. Performance Optimizations

### 7.1 Image Processing
**Issue**: Image resizing and encoding happens on the main thread.

**Current Code** (swift_llm_bridge.swift:1078-1096):
```swift
private func encodeImageToBase64(_ image: PlatformImage, compressionQuality: CGFloat = 0.8) -> String? {
    #if canImport(UIKit)
    let resizedImage = resizeImageIfNeeded(image, maxSize: 1024)
    guard let imageData = resizedImage.jpegData(compressionQuality: compressionQuality) else {
        return nil
    }
    return imageData.base64EncodedString()
    #endif
}
```

**Recommendation**: Move image processing to background thread.

**Proposed Solution**:
```swift
actor ImageProcessor {
    func processImage(_ image: PlatformImage, maxSize: CGFloat = 1024, compressionQuality: CGFloat = 0.8) async -> String? {
        let resizedImage = resizeImageIfNeeded(image, maxSize: maxSize)

        #if canImport(UIKit)
        guard let imageData = resizedImage.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        #elseif canImport(AppKit)
        guard let cgImage = resizedImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let bitmapRep = NSBitmapImageRep(cgImage: cgImage),
              let imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) else {
            return nil
        }
        #endif

        return imageData.base64EncodedString()
    }

    private func resizeImageIfNeeded(_ image: PlatformImage, maxSize: CGFloat) -> PlatformImage {
        // ... existing resize logic
    }
}

// Usage:
let processor = ImageProcessor()
let base64Image = await processor.processImage(image)
```

---

### 7.2 Database Query Optimization
**Issue**: Complex nested queries could be optimized.

**Current Code** (DatabaseManager.swift:210-219):
```swift
let query = """
    SELECT q1.id, q1.groupid, q1.instruction, q1.question, q1.answer, q1.image, q1.created, q1.engine, q1.title, q1.provider, q1.model
    FROM questions q1
    INNER JOIN (
        SELECT groupid, MIN(id) as min_id, MAX(created) as max_created
        FROM questions
        GROUP BY groupid
    ) q2 ON q1.groupid = q2.groupid AND q1.id = q2.min_id
    ORDER BY q2.max_created DESC;
"""
```

**Recommendation**: Add indexes and simplify queries where possible.

**Proposed Solution**:
```swift
// Add indexes during table creation
private func createTable() {
    let createTableQuery = """
    CREATE TABLE IF NOT EXISTS questions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      groupid TEXT NOT NULL,
      instruction TEXT,
      question TEXT,
      answer TEXT,
      image TEXT,
      created TEXT,
      engine TEXT,
      title TEXT,
      provider TEXT,
      model TEXT
    );
    """

    // Add indexes for better query performance
    let createIndexes = [
        "CREATE INDEX IF NOT EXISTS idx_groupid ON questions(groupid);",
        "CREATE INDEX IF NOT EXISTS idx_created ON questions(created);",
        "CREATE INDEX IF NOT EXISTS idx_groupid_created ON questions(groupid, created);"
    ]

    // Execute create table and indexes
}

// Optimize query using window functions (if supported)
let optimizedQuery = """
    SELECT id, groupid, instruction, question, answer, image, created, engine, title, provider, model,
           ROW_NUMBER() OVER (PARTITION BY groupid ORDER BY id ASC) as rn,
           MAX(created) OVER (PARTITION BY groupid) as max_created
    FROM questions
    WHERE rn = 1
    ORDER BY max_created DESC;
"""
```

---

## 8. Testing

### 8.1 Lack of Unit Tests
**Critical Issue**: No automated tests found in the codebase.

**Recommendation**: Implement comprehensive unit and integration tests.

**Proposed Solution**:
```swift
// Tests/ChatViewModelTests.swift
import XCTest
@testable import macollama

final class ChatViewModelTests: XCTestCase {
    var sut: ChatViewModel!
    var mockRepository: MockChatRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockChatRepository()
        sut = ChatViewModel(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    func testStartNewChat_ClearsMessages() {
        // Given
        sut.messages = [ChatMessage(id: 1, content: "Test", isUser: true, timestamp: Date())]

        // When
        sut.startNewChat()

        // Then
        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertNil(sut.selectedImage)
        XCTAssertEqual(sut.messageText, "")
    }

    func testLoadChat_LoadsMessagesFromRepository() async {
        // Given
        let groupId = "test-group-id"
        let expectedMessages = [/* mock messages */]
        mockRepository.mockMessages = expectedMessages

        // When
        await sut.loadChat(groupId: groupId)

        // Then
        XCTAssertEqual(sut.messages.count, expectedMessages.count)
    }
}

// Mock repository for testing
class MockChatRepository: ChatRepository {
    var mockMessages: [ChatMessage] = []
    var saveCallCount = 0

    func fetchChatHistory(groupId: String) async throws -> [ChatMessage] {
        return mockMessages
    }

    func saveMessage(groupId: String, question: String, answer: String, image: PlatformImage?, metadata: ChatMetadata) async throws {
        saveCallCount += 1
    }
}
```

---

### 8.2 Networking Tests
**Recommendation**: Create mock network services for testing.

**Proposed Solution**:
```swift
protocol NetworkService {
    func sendRequest<T: Decodable>(_ request: URLRequest) async throws -> T
}

class MockNetworkService: NetworkService {
    var mockResponse: Any?
    var mockError: Error?

    func sendRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        if let error = mockError {
            throw error
        }

        guard let response = mockResponse as? T else {
            throw NetworkError.invalidResponse
        }

        return response
    }
}

// Test
func testGenerateResponse_ReturnsStreamedChunks() async throws {
    // Given
    let mockService = MockNetworkService()
    mockService.mockResponse = ["chunk1", "chunk2", "chunk3"]
    let sut = LLMService(networkService: mockService)

    // When
    let stream = try await sut.generateResponse(prompt: "Test", model: "test-model")
    var chunks: [String] = []

    for try await chunk in stream {
        chunks.append(chunk)
    }

    // Then
    XCTAssertEqual(chunks.count, 3)
}
```

---

## 9. Security Improvements

### 9.1 API Key Storage
**Issue**: API keys stored in UserDefaults are not encrypted.

**Recommendation**: Use Keychain for sensitive data.

**Proposed Solution**:
```swift
import Security

struct KeychainManager {
    static func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func retrieve(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.retrieveFailed(status)
        }

        return result as? Data
    }
}

// Usage:
class SecureConfigurationManager {
    func saveAPIKey(_ key: String, for provider: LLMProvider) throws {
        guard let data = key.data(using: .utf8) else {
            throw ConfigurationError.invalidKey
        }
        try KeychainManager.save(key: "\(provider.rawValue)_api_key", data: data)
    }

    func getAPIKey(for provider: LLMProvider) throws -> String? {
        guard let data = try KeychainManager.retrieve(key: "\(provider.rawValue)_api_key"),
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key
    }
}
```

---

### 9.2 Input Validation
**Issue**: Limited input validation for user-provided data.

**Recommendation**: Add comprehensive validation.

**Proposed Solution**:
```swift
struct InputValidator {
    static func validateURL(_ urlString: String) -> Result<URL, ValidationError> {
        guard !urlString.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure(.emptyInput)
        }

        guard let url = URL(string: urlString) else {
            return .failure(.invalidURL)
        }

        guard ["http", "https"].contains(url.scheme?.lowercased()) else {
            return .failure(.invalidScheme)
        }

        return .success(url)
    }

    static func validateAPIKey(_ key: String) -> Result<String, ValidationError> {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .failure(.emptyInput)
        }

        guard trimmed.count >= 10 else {
            return .failure(.tooShort)
        }

        return .success(trimmed)
    }
}

enum ValidationError: LocalizedError {
    case emptyInput
    case invalidURL
    case invalidScheme
    case tooShort

    var errorDescription: String? {
        switch self {
        case .emptyInput: return "Input cannot be empty"
        case .invalidURL: return "Invalid URL format"
        case .invalidScheme: return "URL must use http or https"
        case .tooShort: return "API key is too short"
        }
    }
}
```

---

## 10. Code Organization

### 10.1 File Size
**Issue**: Some files are too large (swift_llm_bridge.swift: 1154 lines, DatabaseManager.swift: 695 lines)

**Recommendation**: Break large files into smaller, focused modules.

**Proposed Solution**:
```
Services/Network/
├── LLMBridge.swift (core class, ~200 lines)
├── LLMBridge+Streaming.swift (streaming methods)
├── LLMBridge+RequestBuilding.swift (request creation)
├── LLMBridge+SSEParsing.swift (SSE parsing)
├── LLMBridge+ImageProcessing.swift (image utilities)
└── Providers/
    ├── OllamaProvider.swift
    ├── ClaudeProvider.swift
    ├── OpenAIProvider.swift
    └── LMStudioProvider.swift

Services/Persistence/
├── DatabaseManager.swift (core operations, ~200 lines)
├── DatabaseManager+Queries.swift (query methods)
├── DatabaseManager+Migrations.swift (schema migrations)
└── DatabaseManager+Debug.swift (debug utilities, DEBUG only)
```

---

## 11. Modern Swift Features

### 11.1 Use Swift Concurrency
**Recommendation**: Leverage async/await more consistently.

**Current Code** (LLMService.swift:210-214):
```swift
private func fetchChatHistory() async throws -> [(question: String, answer: String)] {
    let groupId = ChatViewModel.shared.chatId.uuidString
    let results = try DatabaseManager.shared.fetchQuestionsByGroupId(groupId)
    return results.map { (question: $0.question, answer: $0.answer) }
}
```

**Proposed Solution**:
```swift
// Make DatabaseManager async
actor DatabaseManager {
    func fetchQuestionsByGroupId(_ groupId: String) async throws -> [QuestionResult] {
        // Async database operations
    }
}

// Usage becomes fully async
private func fetchChatHistory() async throws -> [(question: String, answer: String)] {
    let groupId = ChatViewModel.shared.chatId.uuidString
    let results = try await DatabaseManager.shared.fetchQuestionsByGroupId(groupId)
    return results.map { (question: $0.question, answer: $0.answer) }
}
```

---

### 11.2 Result Builders
**Recommendation**: Use result builders for complex view hierarchies.

**Proposed Solution**:
```swift
@resultBuilder
struct ConditionalViewBuilder {
    static func buildBlock(_ components: any View...) -> some View {
        VStack {
            ForEach(0..<components.count, id: \.self) { index in
                AnyView(components[index])
            }
        }
    }
}
```

---

## 12. Documentation

### 12.1 Missing Documentation
**Issue**: Most methods lack documentation comments.

**Recommendation**: Add comprehensive documentation.

**Proposed Solution**:
```swift
/// Generates a streaming response from the selected LLM provider.
///
/// This method creates a new chat session if needed, processes any attached images,
/// and streams the response back token by token.
///
/// - Parameters:
///   - prompt: The user's input prompt
///   - image: Optional image attachment for vision-capable models
///   - model: The specific model to use for generation
/// - Returns: An async throwing stream of response chunks
/// - Throws: `LLMError` if the request fails or configuration is invalid
///
/// - Important: Call `updateConfiguration()` before using this method if settings have changed.
///
/// Example:
/// ```swift
/// let stream = try await service.generateResponse(
///     prompt: "Describe this image",
///     image: selectedImage,
///     model: "gpt-4o"
/// )
///
/// for try await chunk in stream {
///     print(chunk, terminator: "")
/// }
/// ```
func generateResponse(prompt: String, image: PlatformImage? = nil, model: String) async throws -> AsyncThrowingStream<String, Error> {
    // Implementation
}
```

---

## Priority Recommendations

### Critical (Fix Immediately)
1. **Error Handling**: Stop swallowing errors silently
2. **API Key Security**: Move sensitive data to Keychain
3. **Remove fatalError**: Replace with proper error handling
4. **Unit Tests**: Start with core business logic tests

### High Priority
1. **Code Duplication**: Extract SSE parsing and request building
2. **Database Migrations**: Implement proper migration system
3. **Remove Debug Code**: Clean up or conditionally compile
4. **Dependency Injection**: Reduce singleton usage

### Medium Priority
1. **SwiftUI Optimization**: Consolidate onChange handlers
2. **Performance**: Move image processing to background
3. **Documentation**: Add comprehensive code documentation
4. **File Organization**: Break up large files

### Low Priority (Nice to Have)
1. **ORM Integration**: Consider GRDB for type-safe database operations
2. **Result Builders**: Use for complex view hierarchies
3. **Localization**: Expand language support

---

## Conclusion

The Swift LLM Bridge project has a solid foundation with good architectural patterns and cross-platform support. The main areas for improvement are:

1. **Robustness**: Better error handling and validation
2. **Maintainability**: Reduce duplication and improve organization
3. **Testability**: Add comprehensive test coverage
4. **Security**: Secure sensitive data properly
5. **Performance**: Optimize heavy operations

Implementing these recommendations will significantly improve code quality, maintainability, and user experience. Start with the critical items and work through the priority list systematically.

---

**Generated**: 2025-10-22
**Project**: Swift LLM Bridge
**Lines of Code Analyzed**: ~4,000+ lines across 28 Swift files
