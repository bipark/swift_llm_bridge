# Swift LLM Bridge - Unit Tests

This directory contains unit tests for the Swift LLM Bridge project.

## Test Coverage

### ChatViewModelTests
Tests for the `ChatViewModel` class covering:
- State management (messages, chat IDs, providers)
- Provider normalization (handling various input formats)
- Error handling
- Chat initialization and cleanup

### KeychainManagerTests
Tests for the `KeychainManager` and `SecureConfigurationManager` classes covering:
- Secure storage and retrieval of API keys
- Data persistence in macOS Keychain
- Migration from UserDefaults to Keychain
- Multi-provider API key management
- Special character and Unicode handling

## Running Tests

### From Xcode
1. Open `macollama.xcodeproj` in Xcode
2. Select the test target
3. Press `Cmd+U` to run all tests
4. Or use the Test Navigator (`Cmd+6`) to run individual test classes or methods

### From Command Line
```bash
# Run all tests
xcodebuild test -scheme macollama -destination 'platform=macOS'

# Run specific test class
xcodebuild test -scheme macollama -destination 'platform=macOS' -only-testing:ChatViewModelTests

# Run with coverage
xcodebuild test -scheme macollama -destination 'platform=macOS' -enableCodeCoverage YES
```

### Using Swift Package Manager (if configured)
```bash
swift test
```

## Test Requirements

### Keychain Tests
The Keychain tests require:
- macOS Keychain access (automatic in normal Xcode tests)
- May require keychain access permissions in CI environments
- Tests automatically clean up after themselves

### Database Tests
Database tests (future addition) will require:
- Write access to temporary directory
- SQLite3 framework (included in macOS)

## CI/CD Integration

For continuous integration, add these tests to your CI pipeline:

```yaml
# GitHub Actions example
- name: Run tests
  run: |
    xcodebuild test \
      -scheme macollama \
      -destination 'platform=macOS' \
      -enableCodeCoverage YES
```

## Test Organization

```
Tests/
├── README.md                          # This file
├── ChatViewModelTests/
│   └── ChatViewModelTests.swift      # ChatViewModel unit tests
└── KeychainManagerTests/
    └── KeychainManagerTests.swift    # Keychain security tests
```

## Adding New Tests

When adding new tests:
1. Create a new directory under `Tests/` for each module being tested
2. Name test files with the suffix `Tests.swift`
3. Ensure tests are independent and clean up after themselves
4. Add documentation comments explaining what is being tested
5. Update this README with new test coverage information

## Best Practices

- **Isolation**: Each test should be independent and not rely on other tests
- **Cleanup**: Use `tearDown()` to clean up test data (Keychain, UserDefaults, files)
- **Naming**: Use descriptive test names following the pattern `test<MethodName>_<Scenario>_<ExpectedResult>`
- **Assertions**: Use appropriate XCTest assertions for clarity
- **Documentation**: Add comments explaining complex test scenarios

## Coverage Goals

Current coverage (as of initial implementation):
- ChatViewModel: ~60% (core state management)
- KeychainManager: ~80% (all public APIs)
- DatabaseManager: 0% (tests pending)
- LLMService: 0% (tests pending)

Target coverage: 70%+ for critical business logic

## Known Limitations

1. **Singleton Testing**: ChatViewModel is a singleton, making complete isolation difficult. Consider dependency injection in future refactoring.
2. **Async Testing**: Some tests may need longer timeouts for async operations.
3. **Keychain Permissions**: CI environments may need special keychain configuration.

## Future Test Additions

Planned test coverage:
- [ ] DatabaseManager tests (CRUD operations, migrations)
- [ ] LLMService tests (with mock networking)
- [ ] LLMBridge tests (request building, SSE parsing)
- [ ] Integration tests (end-to-end workflows)
- [ ] UI tests (SwiftUI view testing)
- [ ] Performance tests (large message histories)

## Troubleshooting

### Keychain Access Denied
If Keychain tests fail with access denied:
- Ensure running tests from Xcode (not command line without proper entitlements)
- Check that Keychain Access is enabled in test target capabilities

### Database Connection Errors
If database tests fail:
- Verify write permissions in temporary directory
- Check SQLite3 framework is linked
- Ensure database files are cleaned up between tests

### Timeout Errors
If async tests timeout:
- Increase timeout values in `wait(for:timeout:)`
- Check network connectivity for integration tests
- Verify background queue operations complete

## Contributing

When contributing tests:
1. Follow existing test patterns and naming conventions
2. Ensure all tests pass before submitting PR
3. Add tests for new features or bug fixes
4. Update this README with new test information
5. Aim for >70% code coverage for new code
