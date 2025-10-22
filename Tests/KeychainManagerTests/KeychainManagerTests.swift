import XCTest
@testable import macollama

/// Unit tests for KeychainManager
/// These tests verify secure storage and retrieval of sensitive data
final class KeychainManagerTests: XCTestCase {

    let testKey = "test_keychain_key_12345"
    let testValue = "test_secret_value"

    override func tearDown() {
        // Clean up test data
        try? KeychainManager.delete(key: testKey)
        super.tearDown()
    }

    // MARK: - Save Tests

    func testSaveString_StoresValueInKeychain() throws {
        // When
        try KeychainManager.save(key: testKey, value: testValue)

        // Then
        let retrieved = try KeychainManager.retrieve(key: testKey)
        XCTAssertEqual(retrieved, testValue, "Retrieved value should match saved value")
    }

    func testSaveData_StoresDataInKeychain() throws {
        // Given
        let testData = testValue.data(using: .utf8)!

        // When
        try KeychainManager.save(key: testKey, data: testData)

        // Then
        let retrievedData = try KeychainManager.retrieveData(key: testKey)
        XCTAssertEqual(retrievedData, testData, "Retrieved data should match saved data")
    }

    func testSave_OverwritesExistingValue() throws {
        // Given
        try KeychainManager.save(key: testKey, value: "old_value")

        // When
        try KeychainManager.save(key: testKey, value: testValue)

        // Then
        let retrieved = try KeychainManager.retrieve(key: testKey)
        XCTAssertEqual(retrieved, testValue, "Should overwrite with new value")
    }

    // MARK: - Retrieve Tests

    func testRetrieve_ReturnsNilForNonExistentKey() throws {
        // Given
        let nonExistentKey = "key_that_does_not_exist_54321"

        // When
        let retrieved = try KeychainManager.retrieve(key: nonExistentKey)

        // Then
        XCTAssertNil(retrieved, "Should return nil for non-existent key")
    }

    func testRetrieve_HandlesEmptyString() throws {
        // Given
        let emptyString = ""
        try KeychainManager.save(key: testKey, value: emptyString)

        // When
        let retrieved = try KeychainManager.retrieve(key: testKey)

        // Then
        XCTAssertEqual(retrieved, emptyString, "Should handle empty strings")
    }

    func testRetrieve_HandlesSpecialCharacters() throws {
        // Given
        let specialValue = "test!@#$%^&*()_+-={}[]|:;<>?,./~`"
        try KeychainManager.save(key: testKey, value: specialValue)

        // When
        let retrieved = try KeychainManager.retrieve(key: testKey)

        // Then
        XCTAssertEqual(retrieved, specialValue, "Should handle special characters")
    }

    func testRetrieve_HandlesUnicodeCharacters() throws {
        // Given
        let unicodeValue = "Hello 世界 🌍 Привет مرحبا"
        try KeychainManager.save(key: testKey, value: unicodeValue)

        // When
        let retrieved = try KeychainManager.retrieve(key: testKey)

        // Then
        XCTAssertEqual(retrieved, unicodeValue, "Should handle Unicode characters")
    }

    // MARK: - Delete Tests

    func testDelete_RemovesValueFromKeychain() throws {
        // Given
        try KeychainManager.save(key: testKey, value: testValue)
        XCTAssertTrue(KeychainManager.exists(key: testKey), "Value should exist before deletion")

        // When
        try KeychainManager.delete(key: testKey)

        // Then
        XCTAssertFalse(KeychainManager.exists(key: testKey), "Value should not exist after deletion")
    }

    func testDelete_DoesNotThrowForNonExistentKey() {
        // Given
        let nonExistentKey = "key_that_does_not_exist_67890"

        // When/Then - Should not throw
        XCTAssertNoThrow(try KeychainManager.delete(key: nonExistentKey))
    }

    // MARK: - Exists Tests

    func testExists_ReturnsTrueForExistingKey() throws {
        // Given
        try KeychainManager.save(key: testKey, value: testValue)

        // When
        let exists = KeychainManager.exists(key: testKey)

        // Then
        XCTAssertTrue(exists, "Should return true for existing key")
    }

    func testExists_ReturnsFalseForNonExistentKey() {
        // Given
        let nonExistentKey = "key_that_does_not_exist_11111"

        // When
        let exists = KeychainManager.exists(key: nonExistentKey)

        // Then
        XCTAssertFalse(exists, "Should return false for non-existent key")
    }
}

// MARK: - SecureConfigurationManager Tests

final class SecureConfigurationManagerTests: XCTestCase {

    let manager = SecureConfigurationManager.shared

    override func tearDown() {
        // Clean up test data
        try? manager.deleteAPIKey(for: .claude)
        try? manager.deleteAPIKey(for: .openai)
        try? manager.deleteAPIKey(for: .ollama)
        try? manager.deleteAPIKey(for: .lmstudio)
        super.tearDown()
    }

    // MARK: - API Key Management Tests

    func testSaveAPIKey_StoresKeyForProvider() throws {
        // Given
        let testKey = "sk-test-api-key-12345"

        // When
        try manager.saveAPIKey(testKey, for: .claude)

        // Then
        let retrieved = try manager.getAPIKey(for: .claude)
        XCTAssertEqual(retrieved, testKey, "Retrieved API key should match saved key")
    }

    func testGetAPIKey_ReturnsNilForNonExistentKey() throws {
        // When
        let retrieved = try manager.getAPIKey(for: .claude)

        // Then
        XCTAssertNil(retrieved, "Should return nil when no key is stored")
    }

    func testHasAPIKey_ReturnsTrueWhenKeyExists() throws {
        // Given
        try manager.saveAPIKey("test-key", for: .openai)

        // When
        let hasKey = manager.hasAPIKey(for: .openai)

        // Then
        XCTAssertTrue(hasKey, "Should return true when key exists")
    }

    func testHasAPIKey_ReturnsFalseWhenKeyDoesNotExist() {
        // When
        let hasKey = manager.hasAPIKey(for: .lmstudio)

        // Then
        XCTAssertFalse(hasKey, "Should return false when key does not exist")
    }

    func testDeleteAPIKey_RemovesKeyForProvider() throws {
        // Given
        try manager.saveAPIKey("test-key", for: .claude)
        XCTAssertTrue(manager.hasAPIKey(for: .claude), "Key should exist before deletion")

        // When
        try manager.deleteAPIKey(for: .claude)

        // Then
        XCTAssertFalse(manager.hasAPIKey(for: .claude), "Key should not exist after deletion")
    }

    func testSaveAPIKey_SupportsMultipleProviders() throws {
        // Given
        let claudeKey = "claude-key-123"
        let openaiKey = "openai-key-456"

        // When
        try manager.saveAPIKey(claudeKey, for: .claude)
        try manager.saveAPIKey(openaiKey, for: .openai)

        // Then
        let retrievedClaude = try manager.getAPIKey(for: .claude)
        let retrievedOpenAI = try manager.getAPIKey(for: .openai)

        XCTAssertEqual(retrievedClaude, claudeKey)
        XCTAssertEqual(retrievedOpenAI, openaiKey)
    }

    // MARK: - Migration Tests

    func testMigrateFromUserDefaults_MovesClaudeAPIKey() throws {
        // Given
        let testKey = "test-claude-key-migration"
        UserDefaults.standard.set(testKey, forKey: "claudeApiKey")

        // When
        manager.migrateFromUserDefaults()

        // Then
        let retrievedKey = try manager.getAPIKey(for: .claude)
        XCTAssertEqual(retrievedKey, testKey, "Should migrate Claude API key")

        // Verify removal from UserDefaults
        let userDefaultsValue = UserDefaults.standard.string(forKey: "claudeApiKey")
        XCTAssertNil(userDefaultsValue, "Should remove key from UserDefaults after migration")
    }

    func testMigrateFromUserDefaults_MovesOpenAIAPIKey() throws {
        // Given
        let testKey = "test-openai-key-migration"
        UserDefaults.standard.set(testKey, forKey: "openaiApiKey")

        // When
        manager.migrateFromUserDefaults()

        // Then
        let retrievedKey = try manager.getAPIKey(for: .openai)
        XCTAssertEqual(retrievedKey, testKey, "Should migrate OpenAI API key")

        // Verify removal from UserDefaults
        let userDefaultsValue = UserDefaults.standard.string(forKey: "openaiApiKey")
        XCTAssertNil(userDefaultsValue, "Should remove key from UserDefaults after migration")
    }

    func testMigrateFromUserDefaults_IgnoresEmptyKeys() {
        // Given
        UserDefaults.standard.set("", forKey: "claudeApiKey")
        UserDefaults.standard.set("   ", forKey: "openaiApiKey")

        // When
        manager.migrateFromUserDefaults()

        // Then
        XCTAssertFalse(manager.hasAPIKey(for: .claude), "Should not migrate empty Claude key")
        XCTAssertFalse(manager.hasAPIKey(for: .openai), "Should not migrate whitespace-only OpenAI key")
    }

    func testMigrateFromUserDefaults_HandlesNonExistentKeys() {
        // Given - ensure keys don't exist
        UserDefaults.standard.removeObject(forKey: "claudeApiKey")
        UserDefaults.standard.removeObject(forKey: "openaiApiKey")

        // When/Then - should not crash
        XCTAssertNoThrow(manager.migrateFromUserDefaults())
    }
}
