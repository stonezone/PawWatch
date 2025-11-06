# Tests

Unit and integration tests for pawWatch.

## Structure

- **AppTests/**: Tests for iOS app components
- **WatchTests/**: Tests for watchOS app components

## Running Tests

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter AppTests

# Run with coverage
swift test --enable-code-coverage
```

## Test Strategy

- Unit tests for all services and business logic
- Integration tests for WatchConnectivity
- UI tests for critical user flows
- Performance tests for GPS processing

## Coverage Goals

- Services: 90%+
- Models: 85%+
- ViewModels: 80%+
