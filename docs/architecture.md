# brownpaw Architecture

## Overview

brownpaw is built using Flutter to provide a cross-platform whitewater kayaking logbook with live river data integration. The architecture follows clean architecture principles with an offline-first approach to ensure reliability in areas with poor connectivity.

## Architecture Pattern

We follow a **layered architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│  (UI, Widgets, State Management)        │
├─────────────────────────────────────────┤
│         Application Layer               │
│     (Use Cases, Business Logic)         │
├─────────────────────────────────────────┤
│           Domain Layer                  │
│   (Entities, Repository Interfaces)     │
├─────────────────────────────────────────┤
│            Data Layer                   │
│  (Repositories, Data Sources, DTOs)     │
└─────────────────────────────────────────┘
```

## Core Layers

### 1. Presentation Layer

**Responsibility:** UI components, user interaction, and presentation logic.

**Structure:**
```
lib/
├── screens/
│   ├── home/
│   ├── river_levels/
│   ├── run_info/
│   └── logbook/
├── widgets/
│   ├── common/
│   └── feature_specific/
└── theme/
    └── app_theme.dart
```

**Key Components:**
- **Screens:** Full-page views for each feature
- **Widgets:** Reusable UI components
- **State Management:** BLoC pattern for predictable state flow
- **Navigation:** Declarative routing with Go Router

### 2. Application Layer

**Responsibility:** Orchestrates business logic and use cases.

**Structure:**
```
lib/
├── blocs/
│   ├── river_levels/
│   ├── runs/
│   └── logbook/
└── use_cases/
    ├── get_river_levels.dart
    ├── save_log_entry.dart
    └── fetch_run_info.dart
```

**Pattern:** Each use case represents a single business operation.

### 3. Domain Layer

**Responsibility:** Core business entities and contracts.

**Structure:**
```
lib/
├── models/
│   ├── river.dart
│   ├── river_level.dart
│   ├── run.dart
│   └── log_entry.dart
└── repositories/
    ├── river_repository.dart
    ├── run_repository.dart
    └── logbook_repository.dart
```

**Key Concepts:**
- **Entities:** Pure Dart objects representing business concepts
- **Repository Interfaces:** Define contracts for data access
- **Value Objects:** Immutable objects (e.g., coordinates, difficulty class)

### 4. Data Layer

**Responsibility:** Data persistence, API communication, and data transformation.

**Structure:**
```
lib/
├── repositories/
│   └── implementations/
│       ├── river_repository_impl.dart
│       ├── run_repository_impl.dart
│       └── logbook_repository_impl.dart
├── data_sources/
│   ├── remote/
│   │   ├── firestore_river_levels.dart
│   │   ├── firestore_runs.dart
│   │   └── cloud_functions_service.dart
│   └── local/
│       ├── hive_storage.dart
│       └── shared_preferences_storage.dart
└── dto/
    ├── river_level_dto.dart
    └── run_dto.dart
```

## State Management

### BLoC Pattern (Business Logic Component)

**Why BLoC:**
- Clear separation of business logic from UI
- Predictable state changes
- Excellent testability
- Built-in stream handling for async operations

**Structure:**
```dart
// Events
abstract class RiverLevelsEvent {}
class FetchRiverLevels extends RiverLevelsEvent {}
class RefreshRiverLevels extends RiverLevelsEvent {}

// States
abstract class RiverLevelsState {}
class RiverLevelsLoading extends RiverLevelsState {}
class RiverLevelsLoaded extends RiverLevelsState {
  final List<RiverLevel> levels;
}
class RiverLevelsError extends RiverLevelsState {
  final String message;
}

// BLoC
class RiverLevelsBloc extends Bloc<RiverLevelsEvent, RiverLevelsState> {
  final GetRiverLevelsUseCase getRiverLevels;
  // Implementation...
}
```

## Data Flow

### Offline-First Strategy

1. **Read Path (River Levels):**
   ```
   UI Request → BLoC → Repository → Local Cache (Check)
   ↓
   If expired/missing → Firebase Firestore (River Levels Collection)
   ↓
   Update Cache → Return Data
   ↓
   Return Cached Data
   
   Background Process:
   Cloud Functions (Scheduled) → Environment Canada API → Firebase Firestore
   ```

2. **Read Path (Runs & Other Data):**
   ```
   UI Request → BLoC → Repository → Local Cache (Check)
   ↓
   If expired/missing → Firebase Firestore → Update Cache → Return Data
   ↓
   Return Cached Data
   ```

3. **Write Path (User Data):**
   ```
   User Action → BLoC → Repository → Local Storage (Immediate)
   ↓
   Queue for Sync → Background Sync (When Online) → Firebase Firestore
   ```

### Sync Strategy

- **Periodic Background Sync:** Every 60 minutes for river levels
- **User-Initiated Refresh:** Pull-to-refresh on all data views
- **Conflict Resolution:** Last-write-wins for user data
- **Sync Queue:** Failed operations queued and retried

## Feature Modules

### 1. River Levels

**Data Source:** Firebase Firestore (populated by Cloud Functions)

**Data Pipeline:**
- Cloud Functions fetch from Environment Canada API (scheduled every 60 min)
- Data stored in Firestore `river_levels` collection
- App reads directly from Firestore with real-time listeners

**Components:**
- Real-time level monitoring
- Historical trend visualization
- Favorite rivers quick access
- Alert notifications for level changes

**Caching Strategy:**
- Cache duration: 60 minutes
- Firestore offline persistence enabled
- Real-time updates when online
- Offline access to last synced data

### 2. Run Information

**Data Source:** Firebase Firestore (community-contributed)

**Components:**
- Run database with search/filter
- Detailed run pages (class, length, gradient, hazards)
- Photo galleries
- Access/logistics information
- User reviews and beta

**Caching Strategy:**
- Full run metadata cached locally
- Images cached on-demand
- Incremental updates for modified runs

### 3. Logbook

**Data Source:** Local-first with cloud backup

**Components:**
- Log entry creation/editing
- Photo attachments
- Statistics and insights
- Export capabilities
- Privacy controls

**Storage Strategy:**
- Primary: Local SQLite/Hive
- Backup: Firebase Firestore (encrypted)
- Photos: Compressed locally, uploaded to Cloud Storage

## Technology Stack

### Core Framework
- **Flutter:** 3.10+
- **Dart:** 3.10+

### State Management
- **flutter_bloc:** ^8.1.0 - BLoC pattern implementation
- **equatable:** For value equality in states/events

### Data & Storage
- **hive:** Local NoSQL database
- **drift:** SQLite ORM for structured data
- **shared_preferences:** Simple key-value storage
- **cloud_firestore:** Cloud data sync
- **firebase_storage:** Photo/media storage

### Networking
- **connectivity_plus:** Network status monitoring
- **firebase_core:** Firebase initialization
- **cloud_functions:** Trigger cloud functions when needed

### Background Processing
- **workmanager:** Background task scheduling
- **flutter_local_notifications:** User notifications

### UI & Navigation
- **go_router:** Declarative routing
- **cached_network_image:** Image caching
- **fl_chart:** Data visualization
- **shimmer:** Loading skeletons

### Development Tools
- **freezed:** Immutable data classes
- **json_serializable:** JSON serialization
- **mockito:** Unit testing
- **flutter_test:** Widget testing

## Data Models

### Core Entities

```dart
// River
class River {
  final String id;
  final String name;
  final String region;
  final Coordinates putIn;
  final Coordinates takeOut;
  final List<String> stationIds; // Environment Canada stations
}

// River Level
class RiverLevel {
  final String stationId;
  final String riverId;
  final double level; // meters
  final double flow; // m³/s
  final DateTime timestamp;
  final LevelTrend trend;
}

// Run
class Run {
  final String id;
  final String riverId;
  final String name;
  final DifficultyClass difficulty;
  final double length; // kilometers
  final double gradient; // meters per kilometer
  final String description;
  final List<String> hazards;
  final SeasonInfo season;
  final AccessInfo access;
}

// Log Entry
class LogEntry {
  final String id;
  final String runId;
  final DateTime date;
  final double duration; // hours
  final double level; // at time of run
  final DifficultyClass perceivedDifficulty;
  final String notes;
  final List<String> photoUrls;
  final List<String> crew;
  final bool isPrivate;
}
```

## API Integration

brownpaw uses Firebase Cloud Functions (Python) to interact with external APIs like Environment Canada. This keeps the mobile app simple and secure by having it only read from Firebase.

**For detailed API integration documentation, see [api-integration.md](api-integration.md)**

**Key Points:**
- App reads river level data from Firestore only
- Cloud Functions (Python) handle all Environment Canada API calls
- Scheduled function updates river levels every 60 minutes
- Callable functions for admin operations and historical data
- Comprehensive error handling and caching strategies

### Firebase Services

**Firestore Collections:**
- `river_levels` - Current and recent river level data (Cloud Functions managed)
- `river_stations` - Environment Canada station metadata
- `rivers` - River metadata and run information
- `runs` - Detailed run information
- `users` - User profiles
- `logs` - Private logbook entries (user-scoped)
- `community_reviews` - Public run reviews

**Security Rules:**
- `river_levels`: Public read, Cloud Functions write only
- `river_stations`: Public read, Admin write only
- `rivers`/`runs`: Public read, Authenticated write with validation
- `logs`: User-scoped read/write for own data only
- `community_reviews`: Public read, Authenticated write

**Cloud Functions:**
- `updateRiverLevels` - Scheduled data sync from Environment Canada
- `addRiverStation` - Admin function for station management
- `getHistoricalData` - On-demand historical data retrieval
- Data validation and transformation

## Security & Privacy

### Data Protection

1. **User Data:**
   - Logbook entries encrypted at rest
   - Optional cloud backup (opt-in)
   - Local-first storage
   - Export and delete capabilities

2. **Authentication:**
   - Firebase Authentication
   - Anonymous mode supported
   - OAuth providers (Google, Apple)

3. **Network Security:**
   - HTTPS only
   - Certificate pinning for critical APIs
   - API key obfuscation

### Privacy Controls

- **Local-Only Mode:** Full app functionality without cloud sync
- **Private Entries:** Opt-in per log entry
- **Data Export:** JSON format for portability
- **Account Deletion:** Complete data removal

## Performance Optimization

### Strategies

1. **Lazy Loading:**
   - Paginated lists for runs/entries
   - On-demand image loading
   - Deferred initialization of heavy services

2. **Caching:**
   - Multi-level cache (memory → disk → network)
   - Image caching with size limits
   - Intelligent cache invalidation

3. **Background Work:**
   - Offload heavy operations to isolates
   - Background sync during charging
   - Batch API requests

4. **UI Performance:**
   - List virtualization
   - Image optimization (compression, formats)
   - Debounced search
   - Skeleton loaders

## Testing Strategy

### Unit Tests
- Business logic (BLoCs, Use Cases)
- Data transformations (DTOs, Mappers)
- Utility functions
- Target: 80%+ coverage

### Widget Tests
- Individual widget behavior
- State rendering
- User interactions
- Target: Key user flows

### Integration Tests
- End-to-end user scenarios
- API integration
- Database operations
- Critical paths only

### Golden Tests
- UI consistency
- Theme validation
- Responsive layouts

## Build & Deployment

### Environments

- **Development:** Local testing, debug builds
- **Staging:** Pre-release testing, TestFlight/Internal Testing
- **Production:** Public releases

### CI/CD Pipeline

```yaml
# GitHub Actions workflow
1. Code Checkout
2. Dependency Installation
3. Static Analysis (flutter analyze)
4. Tests (unit, widget)
5. Build (iOS, Android, Web)
6. Deploy (Firebase Hosting, App Stores)
```

### Release Process

1. Version bump (semantic versioning)
2. Update changelog
3. Run full test suite
4. Build release artifacts
5. Submit to stores (Google Play, App Store)
6. Deploy web version to Firebase Hosting

## Future Considerations

### Scalability

- **Modular Architecture:** Feature modules as packages
- **Microservices:** Dedicated services for heavy operations
- **CDN:** Global content delivery for images/static assets

### Extensibility

- **Plugin System:** Third-party integrations
- **API:** Public API for data access
- **Webhooks:** Real-time notifications

### Advanced Features

- **Machine Learning:** Flow prediction models
- **Social Features:** Group planning, trip coordination
- **Wearable Integration:** Smartwatch companion app
- **AR Features:** River overlays, hazard markers

---

*This architecture is designed to evolve with the app. Regular reviews and refactoring ensure we maintain code quality and adaptability.*
