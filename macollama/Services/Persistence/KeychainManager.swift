import Foundation
import Security

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to keychain: \(status)"
        case .retrieveFailed(let status):
            return "Failed to retrieve from keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from keychain: \(status)"
        case .invalidData:
            return "Invalid data format"
        }
    }
}

struct KeychainManager {
    /// Saves a string value to the keychain
    /// - Parameters:
    ///   - key: The key to store the value under
    ///   - value: The string value to store
    /// - Throws: KeychainError if save fails
    static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(key: key, data: data)
    }

    /// Saves data to the keychain
    /// - Parameters:
    ///   - key: The key to store the data under
    ///   - data: The data to store
    /// - Throws: KeychainError if save fails
    static func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieves a string value from the keychain
    /// - Parameter key: The key to retrieve
    /// - Returns: The stored string, or nil if not found
    /// - Throws: KeychainError if retrieval fails
    static func retrieve(key: String) throws -> String? {
        guard let data = try retrieveData(key: key) else {
            return nil
        }

        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return string
    }

    /// Retrieves data from the keychain
    /// - Parameter key: The key to retrieve
    /// - Returns: The stored data, or nil if not found
    /// - Throws: KeychainError if retrieval fails
    static func retrieveData(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.retrieveFailed(status)
        }

        return result as? Data
    }

    /// Deletes a value from the keychain
    /// - Parameter key: The key to delete
    /// - Throws: KeychainError if deletion fails
    static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Checks if a key exists in the keychain
    /// - Parameter key: The key to check
    /// - Returns: true if the key exists, false otherwise
    static func exists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

/// Secure configuration manager for API keys and sensitive data
class SecureConfigurationManager {
    static let shared = SecureConfigurationManager()

    private init() {}

    /// Saves an API key for a specific LLM provider
    /// - Parameters:
    ///   - key: The API key to save
    ///   - provider: The LLM provider
    /// - Throws: KeychainError if save fails
    func saveAPIKey(_ key: String, for provider: LLMProvider) throws {
        let keychainKey = "\(provider.rawValue)_api_key"
        try KeychainManager.save(key: keychainKey, value: key)
    }

    /// Retrieves an API key for a specific LLM provider
    /// - Parameter provider: The LLM provider
    /// - Returns: The stored API key, or nil if not found
    /// - Throws: KeychainError if retrieval fails
    func getAPIKey(for provider: LLMProvider) throws -> String? {
        let keychainKey = "\(provider.rawValue)_api_key"
        return try KeychainManager.retrieve(key: keychainKey)
    }

    /// Deletes an API key for a specific LLM provider
    /// - Parameter provider: The LLM provider
    /// - Throws: KeychainError if deletion fails
    func deleteAPIKey(for provider: LLMProvider) throws {
        let keychainKey = "\(provider.rawValue)_api_key"
        try KeychainManager.delete(key: keychainKey)
    }

    /// Checks if an API key exists for a specific provider
    /// - Parameter provider: The LLM provider
    /// - Returns: true if an API key exists, false otherwise
    func hasAPIKey(for provider: LLMProvider) -> Bool {
        let keychainKey = "\(provider.rawValue)_api_key"
        return KeychainManager.exists(key: keychainKey)
    }

    /// Migrates API keys from UserDefaults to Keychain
    /// This should be called once during app migration
    func migrateFromUserDefaults() {
        let migrations: [(key: String, provider: LLMProvider)] = [
            ("claudeApiKey", .claude),
            ("openaiApiKey", .openai)
        ]

        for (userDefaultsKey, provider) in migrations {
            if let apiKey = UserDefaults.standard.string(forKey: userDefaultsKey),
               !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                do {
                    try saveAPIKey(apiKey, for: provider)
                    // Clear from UserDefaults after successful migration
                    UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                    #if DEBUG
                    print("Migrated \(provider.rawValue) API key to Keychain")
                    #endif
                } catch {
                    #if DEBUG
                    print("Failed to migrate \(provider.rawValue) API key: \(error)")
                    #endif
                }
            }
        }
    }
}
