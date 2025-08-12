# GreenStem

A Flutter application built with Clean Architecture principles.

## Project Structure

```
lib/
├── main.dart
├── core/             → Common utilities (constants, themes, services)
│   ├── constants/    → App-wide constants
│   ├── utils/        → Utility functions and helpers
│   ├── theme/        → App theming configuration
│   └── exceptions/   → Custom exception classes
├── data/             → Data layer (API, models, repositories)
│   ├── models/       → Data models (usually from JSON)
│   └── datasources/  → APIs or local DB (e.g., http, sqlite)
├── domain/           → Business logic (use cases, entities, interfaces)
│   └── entities/     → Core app objects
└── presentation/     → UI layer (screens, widgets, state management)
    ├── screens/      → App screens organized by feature
    ├── widgets/      → Shared UI components
    └── providers/    → State management (Riverpod/Provider)
```

## Architecture

This project follows Clean Architecture principles:

- **Presentation Layer**: Contains UI components, screens, and state management
- **Domain Layer**: Contains business logic, entities, and use cases
- **Data Layer**: Contains data models, repositories, and data sources

## Features

- Clean Architecture structure
- Material Design 3
- Dark/Light theme support
- Reusable UI components
- Custom exception handling
- Logging utilities

## Getting Started

This project is a starting point for a Flutter application following best practices.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
