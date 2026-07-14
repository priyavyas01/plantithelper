# PlantIt Helper — Flutter App

Cross-platform mobile app (iOS + Android) for plant identification, health diagnosis, and AI-powered care guidance.

## Stack
- **Flutter / Dart** — cross-platform UI
- **Riverpod** — state management *(decision pending: Riverpod vs BLoC)*
- **go_router** — declarative routing + deep links
- **flutter_secure_storage** — JWT token persistence
- **image_picker** — camera + gallery access
- **flutter_image_compress** — client-side image compression before upload
- **flutter_local_notifications** — care reminders (MVP; FCM for v2)
- **dio** — HTTP client with interceptors for auth headers

## Planned App Structure

```
lib/
├── main.dart                        # Entry point, router setup, token check
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── scan/
│   │   ├── capture_screen.dart      # Camera / gallery picker
│   │   └── preview_screen.dart      # Confirm before submit
│   ├── scan_result/
│   │   └── scan_result_screen.dart  # Species, health, care cards
│   ├── plants/
│   │   ├── my_plants_screen.dart    # Collection grid (home)
│   │   └── plant_detail_screen.dart # Full plant view
│   ├── chat/
│   │   └── chat_screen.dart         # AI chat per plant
│   ├── schedule/
│   │   └── schedule_screen.dart     # Care tasks list
│   └── journal/
│       └── journal_screen.dart      # Notes per plant
├── services/
│   ├── api_service.dart             # dio client + base URL
│   ├── auth_service.dart            # register/login API calls
│   ├── token_service.dart           # flutter_secure_storage read/write/clear
│   ├── plant_service.dart           # plants/scans API calls
│   └── chat_service.dart            # chat API calls
├── models/
│   ├── user.dart
│   ├── plant.dart
│   ├── scan_result.dart
│   ├── chat_message.dart
│   └── schedule_task.dart
└── widgets/
    ├── care_card.dart               # Reusable care requirement card
    ├── health_badge.dart            # Health status chip
    ├── plant_card.dart              # Collection grid card
    └── message_bubble.dart          # Chat bubble
```

## Setup

### Prerequisites
- Flutter SDK `^3.12.2`
- Xcode (iOS) or Android Studio (Android)
- Backend API running (`../plantithelper-api/`)

### Install dependencies
```bash
flutter pub get
```

### Run
```bash
flutter run
```

### Dependencies to add (E1-S2 onwards)
```bash
flutter pub add flutter_secure_storage dio image_picker flutter_image_compress go_router flutter_riverpod cached_network_image flutter_local_notifications
```

## Screen Flow

```
App Launch
  └── Token check
        ├── Valid token  →  My Plants (Home)
        └── No/expired   →  Login → Register

My Plants → FAB → Capture → Preview → Scan Result → [Save] → My Plants

My Plants → tap card → Plant Detail
  ├── Care tab
  ├── Health tab
  ├── History tab
  └── Journal tab
```

## Related
- Backend API: `../plantithelper-api/`
- Story definitions + edge cases: `../plantithelper-api/stories.md`
- Architecture diagrams: `../plantithelper-api/docs/architecture.md`
- Progress log: `../plantithelper-api/TRACKER.md`

## Original Flutter README

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
