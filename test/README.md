# brownpaw Test Suite

## Running Tests

### Run all tests
```bash
flutter test
```

### Run specific test file
```bash
flutter test test/app_test.dart
flutter test test/auth_screen_test.dart
flutter test test/models/river_run_test.dart
flutter test test/models/descent_test.dart
```

### Run tests with coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Test Structure

### Widget Tests
- `test/app_test.dart` - Main app initialization and navigation
- `test/auth_screen_test.dart` - Authentication screen UI tests

### Unit Tests
- `test/models/river_run_test.dart` - RiverRun model tests
- `test/models/descent_test.dart` - Descent model tests

## Test Coverage

Current test coverage focuses on:
- ✅ App initialization and configuration
- ✅ Authentication screen rendering
- ✅ Core data models (RiverRun, Descent)
- ✅ Model serialization/deserialization

### Areas for Future Testing
- [ ] Provider state management logic
- [ ] Integration tests for Firebase interactions
- [ ] Flow data fetching and caching
- [ ] Logbook CRUD operations
- [ ] Favorites management
- [ ] Form validation
- [ ] Error handling

## Notes

These are basic widget and unit tests to establish a testing foundation. For MVP release, these provide:
1. Confidence that the app builds correctly
2. Validation of core data models
3. Basic UI component testing

For production releases beyond MVP, expand test coverage to include integration tests, provider tests, and end-to-end flows.
