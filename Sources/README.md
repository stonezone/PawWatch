# Sources

This directory contains all Swift source code for the pawWatch application.

## Structure

- **App/**: iOS app source code (iPhone interface)
- **WatchApp/**: watchOS app source code (Apple Watch GPS tracker)
- **Shared/**: Shared models, utilities, and constants
- **Services/**: Core services (LocationService, ConnectivityService, etc.)

## Architecture

The codebase follows a clean architecture pattern:

```
┌─────────────────────────────────────┐
│  App/WatchApp (UI Layer)            │
│  - SwiftUI Views                    │
│  - View Models                      │
└───────────────┬─────────────────────┘
                │
┌───────────────▼─────────────────────┐
│  Services (Business Logic)          │
│  - LocationService                  │
│  - ConnectivityService              │
│  - ActivityService                  │
└───────────────┬─────────────────────┘
                │
┌───────────────▼─────────────────────┐
│  Shared (Data Layer)                │
│  - Models                           │
│  - Extensions                       │
│  - Constants                        │
└─────────────────────────────────────┘
```

## Guidelines

- Use Swift 6.2 features and strict concurrency
- Follow iOS 26 Liquid Glass design patterns
- Maintain 0.5s GPS update throttle minimum
- Keep services isolated and testable
