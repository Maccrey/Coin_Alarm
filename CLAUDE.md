# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Commands

### Development Commands
- `flutter pub get` - Install dependencies
- `flutter run` - Run the app in debug mode
- `flutter run --release` - Run in release mode for performance testing
- `flutter run -d web-server --web-port=8080` - Run web version
- `flutter clean && flutter pub get` - Clean build cache and reinstall dependencies

### Code Generation
- `flutter packages pub run build_runner build` - Generate Hive adapters and other code
- `flutter packages pub run build_runner build --delete-conflicting-outputs` - Force regenerate

### Testing Commands
- `flutter test` - Run unit tests
- `flutter test test/notification_service_test.dart` - Run specific test file
- `flutter test test/price_alert_service_test.dart` - Run price alert service tests

### Build Commands
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app
- `flutter build web` - Build web version

### Linting and Analysis
- `flutter analyze` - Run static analysis (uses flutter_lints package)
- `dart format .` - Format code

## Architecture Overview

### MVVM Pattern
This app follows the Model-View-ViewModel pattern with Provider for state management:

- **Models**: Located in `lib/model/` - Data structures with Hive adapters for local storage
- **Views**: Located in `lib/view/screens/` - UI screens and widgets
- **ViewModels**: Located in `lib/viewmodel/` - Business logic and state management using ChangeNotifier
- **Services**: Located in `lib/services/` - External integrations and utilities

### Key Architectural Components

#### State Management
- Uses Provider pattern with ChangeNotifier ViewModels
- Multiple providers are configured in `main.dart` with MultiProvider
- ViewModels handle business logic and expose data to UI components
- Services are injected into ViewModels via constructor or Provider.of()

#### Data Layer
- **Local Storage**: Hive for structured data (price alerts, chart cache, settings)
- **Shared Preferences**: Simple key-value storage via SettingsService
- **Firebase**: Authentication, Firestore for news data, real-time database
- **API Integration**: Upbit and Binance APIs for cryptocurrency data

#### Background Processing
- WorkManager for 15-minute periodic price alert checks
- Background task defined in `callbackDispatcher()` function in main.dart
- Isolated execution with separate Hive initialization in background context
- Platform-aware implementation (disabled for web)

#### Notification System
- AwesomeNotifications for rich local notifications
- Notification channels and permissions managed in NotificationService
- Background notification triggers from price alert monitoring
- Action handling for notification interactions

### Service Architecture

#### Core Services
- **AuthService**: Firebase Authentication integration with biometric support
- **CryptoApiService**: Multi-exchange API wrapper (Upbit, Binance)
- **PriceAlertService**: Price monitoring and alert management with Hive storage
- **NotificationService**: Notification lifecycle and permission management
- **ChartCacheService**: Chart data caching with TTL and offline support
- **HapticService**: Platform-aware haptic feedback system
- **SettingsService**: Centralized app configuration management

#### API Integration
- Factory pattern for multiple exchange APIs
- Retry logic and error handling for network requests
- Rate limiting compliance (Upbit: 10 requests/second)
- Graceful degradation when APIs are unavailable

### Data Models

#### Key Models with Hive Adapters
- **PriceAlert** (typeId: 10): User-configured price alerts with trigger conditions
- **ChartDataModel**: Cached chart data with timestamp for TTL management
- **Coin**: Cryptocurrency data structure for real-time price information
- **News**: News articles from Firebase with caching support

#### Model Generation
- Hive adapters are generated using build_runner
- Generated files follow `.g.dart` naming convention
- Always run code generation after model changes

## Development Patterns

### Error Handling
- Use try-catch blocks with specific error types when possible
- Log errors using `debugPrint()` for development
- Graceful fallbacks for network and API failures
- User-friendly error messages in UI

### Async Operations
- Prefer async/await over Future.then()
- Use FutureBuilder for UI that depends on async data
- Handle loading states and errors in ViewModels
- Use Provider.of() with listen: false for one-time data access

### File Organization
- Follow the existing directory structure strictly
- Keep related functionality together (models, views, viewmodels, services)
- Use descriptive file names that match class names
- Separate widgets into reusable components when appropriate

### Testing Approach
- Write unit tests for service classes and business logic
- Mock external dependencies using mockito
- Test ViewModels independently of UI
- Focus on testing critical paths like price alert logic

## Platform Considerations

### iOS Specific
- Background App Refresh dependency for background tasks
- Biometric authentication using LocalAuthentication framework
- Push notification entitlements in Info.plist
- Firebase configuration in GoogleService-Info.plist

### Android Specific
- Foreground service permissions for background tasks
- Notification channels for Android 8.0+
- Battery optimization exemptions may be needed
- Firebase configuration in google-services.json

### Web Specific
- Background tasks are disabled (WorkManager not available)
- Biometric authentication falls back to standard auth
- Local notifications have limited functionality
- Use conditional compilation with `kIsWeb` check

## Firebase Integration

### Services Used
- **Authentication**: Email/password with biometric login option
- **Firestore**: News articles and user data
- **Realtime Database**: Real-time cryptocurrency data
- **Storage**: Media assets and user uploads

### Security Rules
- Firestore rules restrict user data access by authentication
- Read operations allowed for news data
- Write operations require authentication

### Configuration
- Firebase options are generated and stored in `firebase_options.dart`
- Platform-specific configuration files must be present
- Initialize Firebase before other services in main.dart

## Background Task System

### WorkManager Implementation
- Periodic task runs every 15 minutes
- Callback function `callbackDispatcher()` runs in isolated Dart context
- Separate Hive initialization required in background context
- Input data passed as simple Map<String, String>

### Price Alert Logic
- Fetches current prices from Upbit API in background
- Compares against user-configured price targets
- Triggers notifications and updates alert status
- Graceful handling of API failures and network issues

### Performance Considerations
- Minimize background task execution time
- Use efficient data structures and algorithms
- Avoid heavy computations in background context
- Respect battery optimization constraints

## Common Development Tasks

### Adding New Cryptocurrency Exchanges
1. Extend CryptoApiService with new exchange integration
2. Update fetchCoinPricesForBackground() in main.dart
3. Add exchange-specific error handling
4. Update settings to allow API key configuration

### Adding New Notification Types
1. Define new notification channel in NotificationService
2. Update NotificationContent creation logic
3. Add corresponding action handlers
4. Test on both platforms for consistency

### Adding New Chart Timeframes
1. Update ChartApiService with new timeframe endpoints
2. Extend ChartCacheService for new cache keys
3. Update UI components to support new options
4. Test caching behavior and TTL management

### Modifying Background Task Frequency
1. Update Duration in Workmanager.registerPeriodicTask()
2. Consider platform limitations (iOS minimum 15 minutes)
3. Test battery impact with new frequency
4. Update user documentation if needed

## Important Notes

### Code Generation Dependencies
- Always run `flutter packages pub run build_runner build` after modifying models
- Hive adapters must be regenerated when model fields change
- Check for build_runner conflicts and use --delete-conflicting-outputs if needed

### Testing with Background Tasks
- Background tasks only work on physical devices, not simulators
- Use debug logging to verify background execution
- Test with app backgrounded and device screen off
- Verify notification delivery in various app states

### Firebase Initialization
- Firebase must be initialized before other services
- Handle platform-specific initialization differences (iOS vs Android)
- Use proper error handling for Firebase initialization failures
- Test with different Firebase project configurations

### Performance Best Practices
- Use const constructors where possible
- Implement proper disposal in ViewModels and services
- Cache network responses appropriately
- Minimize widget rebuilds using Consumer and Selector