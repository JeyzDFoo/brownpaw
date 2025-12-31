# brownpaw

**A whitewater kayaking logbook with live river levels.**

brownpaw is an offline-first mobile app that provides kayakers with:
- 🌊 Live river levels from Environment Canada (updated hourly)
- 📊 Historical data and seasonal trends
- 📝 Digital logbook for tracking your runs
- 🗺️ Run information database for BC and Alberta rivers
- 📱 Works offline with local data caching

## Features

### Live River Levels
- Real-time water level and discharge data
- Trend indicators (rising/falling/stable)
- Current conditions updated every hour
- Support for 500+ stations across BC and Alberta

### Historical Analysis
- 5-minute interval data (last 30 days)
- Daily mean data from HYDAT database
- Seasonal patterns and monthly averages
- Interactive charts and graphs

### Digital Logbook
- Track your kayaking sessions
- Record river conditions, difficulty, and notes
- Photo uploads
- Search and filter past runs

### Run Information
- Curated database of whitewater runs
- Difficulty ratings and descriptions
- Access points and shuttle information
- Community-contributed beta

## Tech Stack

- **Frontend:** Flutter 3.10+ (iOS, Android, Web, Desktop)
- **Backend:** Firebase (Firestore, Cloud Functions, Authentication, Storage)
- **Cloud Functions:** Python 3.11+
- **State Management:** BLoC pattern
- **Data Source:** Environment Canada API (OGC API Features)
- **Architecture:** Offline-first with local caching

## Project Structure

```
brownpaw/
├── lib/                      # Flutter application code
│   ├── main.dart            # App entry point
│   └── theme/               # Material 3 theme (river-inspired colors)
├── docs/                     # Documentation
│   ├── design-philosophy.md # Vision and design principles
│   ├── architecture.md      # System architecture
│   ├── api-integration.md   # Cloud Functions design
│   └── firestore-schema.md  # Database schema
├── scripts/                  # Python utilities and data models
│   ├── models.py            # Data models (Station, StationLevel, DailyMean)
│   └── environment_canada/  # API test scripts
│       ├── fetch_station_levels.py    # Real-time data
│       ├── fetch_historical_data.py   # 5-min intervals
│       ├── fetch_daily_means.py       # Daily averages
│       └── list_stations.py           # Station browser
└── functions/                # Cloud Functions (TODO)
```

## Documentation

- **[Design Philosophy](docs/design-philosophy.md)** - Vision, principles, and feature philosophy
- **[Architecture](docs/architecture.md)** - System design and data flow
- **[API Integration](docs/api-integration.md)** - Cloud Functions and external APIs
- **[Firestore Schema](docs/firestore-schema.md)** - Database structure and security rules

## Data Models

Type-safe Python models for Firestore collections:

- **`Station`** - Monitoring station metadata (location, provider, active status)
- **`StationLevel`** - Current real-time water levels (updated hourly)
- **`DailyMean`** - Historical daily averages (HYDAT database)
- **`Provider`** - Multi-provider support (Environment Canada, USGS, etc.)
- **`Trend`** - Water level trend calculation (rising/falling/stable)

See [`scripts/models.py`](scripts/models.py) for implementation details.

## Development Setup

### Prerequisites

- Flutter SDK 3.10+
- Python 3.11+
- Firebase CLI
- Git

### Installation

```bash
# Clone repository
git clone https://github.com/yourusername/brownpaw.git
cd brownpaw

# Install Flutter dependencies
flutter pub get

# Install Python dependencies
cd scripts
pip install -r environment_canada/requirements.txt

# Run the app
flutter run
```

### Testing Environment Canada API

```bash
cd scripts/environment_canada

# Fetch current levels
python3 fetch_station_levels.py 08GA072

# Fetch 3 days of 5-minute data
python3 fetch_historical_data.py 08GA072 3

# Fetch full year of daily means
python3 fetch_daily_means.py 08GA072 2024-01-01 2024-12-31

# Browse stations
python3 list_stations.py
```

## Firebase Setup (TODO)

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase
firebase init
```

## Roadmap

### Phase 1: MVP (Current)
- [x] Design philosophy and architecture
- [x] Flutter app structure with Material 3 theme
- [x] Data models for multi-provider support
- [x] Environment Canada API integration
- [x] Test scripts for real-time and historical data
- [ ] Firebase initialization
- [ ] Cloud Functions implementation
- [ ] Basic station list view

### Phase 2: Core Features
- [ ] Real-time river level display
- [ ] Station search and favorites
- [ ] Historical charts (30 days)
- [ ] Offline data caching
- [ ] User authentication

### Phase 3: Logbook
- [ ] Trip logging interface
- [ ] Photo uploads
- [ ] Search and filtering
- [ ] Export functionality

### Phase 4: Run Information
- [ ] Run database schema
- [ ] Run details view
- [ ] Community contributions
- [ ] Integration with river levels

## Contributing

Contributions are welcome! Please read our contributing guidelines (TODO) before submitting pull requests.

## License

[License TBD]

## Acknowledgments

- **Environment Canada** for providing free public access to hydrometric data
- **Flutter & Firebase** for excellent mobile development tools
- The whitewater kayaking community for inspiration

---

**Note:** This project is currently in active development. Features and documentation are subject to change.
