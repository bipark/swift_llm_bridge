import XCTest
@testable import macollama

/// Basic unit tests for ChatViewModel
/// These tests verify core functionality like state management and error handling
final class ChatViewModelTests: XCTestCase {

    var sut: ChatViewModel!

    override func setUp() {
        super.setUp()
        // Note: ChatViewModel is a singleton, so we're testing the shared instance
        sut = ChatViewModel.shared
        // Clear state before each test
        sut.messages.removeAll()
        sut.selectedImage = nil
        sut.messageText = ""
        sut.error = nil
        sut.showingError = false
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - State Management Tests

    func testStartNewChat_ClearsMessages() {
        // Given
        sut.messages = [
            ChatMessage(id: 1, content: "Test message", isUser: true, timestamp: Date())
        ]
        sut.messageText = "Some text"
        sut.selectedImage = nil

        // When
        sut.startNewChat()

        // Then
        XCTAssertTrue(sut.messages.isEmpty, "Messages should be cleared")
        XCTAssertEqual(sut.messageText, "", "Message text should be cleared")
        XCTAssertNil(sut.selectedImage, "Selected image should be nil")
    }

    func testStartNewChat_GeneratesNewChatId() {
        // Given
        let oldChatId = sut.chatId

        // When
        sut.startNewChat()

        // Then
        XCTAssertNotEqual(sut.chatId, oldChatId, "Should generate a new chat ID")
    }

    func testUpdateProviderAndModel_UpdatesState() {
        // Given
        let newProvider = LLMProvider.claude
        let newModel = "claude-3-5-sonnet-20241022"

        // When
        sut.updateProviderAndModel(newProvider, newModel)

        // Then
        XCTAssertEqual(sut.chatProvider, newProvider, "Provider should be updated")
        XCTAssertEqual(sut.chatModel, newModel, "Model should be updated")
    }

    // MARK: - Provider Normalization Tests

    func testNormalizedProvider_HandlesOllamaVariants() {
        // Given
        let testCases = ["ollama", "Ollama", "OLLAMA", "ollma", "Ollama Server"]

        // When/Then
        for input in testCases {
            let normalized = sut.normalizedProvider(from: input)
            XCTAssertEqual(normalized, .ollama, "Should normalize '\(input)' to .ollama")
        }
    }

    func testNormalizedProvider_HandlesClaudeVariants() {
        // Given
        let testCases = ["claude", "Claude", "CLAUDE", "anthropic", "Anthropic"]

        // When/Then
        for input in testCases {
            let normalized = sut.normalizedProvider(from: input)
            XCTAssertEqual(normalized, .claude, "Should normalize '\(input)' to .claude")
        }
    }

    func testNormalizedProvider_HandlesOpenAIVariants() {
        // Given
        let testCases = ["openai", "OpenAI", "OPENAI", "gpt", "GPT"]

        // When/Then
        for input in testCases {
            let normalized = sut.normalizedProvider(from: input)
            XCTAssertEqual(normalized, .openai, "Should normalize '\(input)' to .openai")
        }
    }

    func testNormalizedProvider_HandlesLMStudioVariants() {
        // Given
        let testCases = ["lmstudio", "LMStudio", "LMSTUDIO", "lm studio", "LM Studio"]

        // When/Then
        for input in testCases {
            let normalized = sut.normalizedProvider(from: input)
            XCTAssertEqual(normalized, .lmstudio, "Should normalize '\(input)' to .lmstudio")
        }
    }

    func testNormalizedProvider_HandlesInvalidInput() {
        // Given
        let invalidInput = "unknown_provider"

        // When
        let normalized = sut.normalizedProvider(from: invalidInput)

        // Then
        XCTAssertNil(normalized, "Should return nil for unknown provider")
    }

    // MARK: - Error Handling Tests

    func testErrorState_CanBeSet() {
        // Given
        let testError = ChatError.loadFailed("test-group-id")

        // When
        sut.error = testError
        sut.showingError = true

        // Then
        XCTAssertNotNil(sut.error, "Error should be set")
        XCTAssertTrue(sut.showingError, "ShowingError should be true")
    }

    func testErrorState_CanBeCleared() {
        // Given
        sut.error = ChatError.saveFailed("test")
        sut.showingError = true

        // When
        sut.error = nil
        sut.showingError = false

        // Then
        XCTAssertNil(sut.error, "Error should be cleared")
        XCTAssertFalse(sut.showingError, "ShowingError should be false")
    }

    // MARK: - Chat ID Tests

    func testChatId_IsValidUUID() {
        // When
        let chatId = sut.chatId

        // Then
        XCTAssertNotNil(chatId, "Chat ID should not be nil")
        // Verify it can be converted to string and back
        let uuidString = chatId.uuidString
        let recreatedUUID = UUID(uuidString: uuidString)
        XCTAssertNotNil(recreatedUUID, "Chat ID should be a valid UUID")
    }

    // MARK: - Integration Tests (require database)

    func testSaveProviderAndModel_DoesNotCrashWithInvalidChatId() {
        // Given
        sut.chatId = UUID() // Fresh UUID not in database

        // When/Then - Should not crash
        sut.saveProviderAndModel()

        // Wait a bit for async operation
        let expectation = XCTestExpectation(description: "Save completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - ChatError Tests

final class ChatErrorTests: XCTestCase {

    func testChatError_LoadFailed_HasDescription() {
        // Given
        let error = ChatError.loadFailed("test-group-id")

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("test-group-id") ?? false)
    }

    func testChatError_SaveFailed_HasDescription() {
        // Given
        let error = ChatError.saveFailed("test reason")

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("test reason") ?? false)
    }

    func testChatError_DatabaseError_HasDescription() {
        // Given
        let underlyingError = NSError(domain: "TestDomain", code: 42, userInfo: nil)
        let error = ChatError.databaseError(underlyingError)

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Database error") ?? false)
    }

    func testChatError_InvalidData_HasDescription() {
        // Given
        let error = ChatError.invalidData

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(error.errorDescription, "Invalid data format")
    }
}
