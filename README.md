# Baby Monitor App

A real-time infant vitals monitoring application built with Flutter. The app connects to a Raspberry Pi backend to display live SpO₂, heart rate (BPM), and temperature readings with alerts for out-of-range values.

## Features

- **Live Monitoring** — Real-time display of SpO₂, pulse, and temperature with animated waveforms and a 60-second trend view
- **Alert System** — Visual alerts when vitals go out of normal range:
  - SpO₂: alerts if < 94%
  - Pulse: alerts if < 60 or > 100 BPM
  - Temperature: alerts if > 85°F
- **History Charts** — View historical vital trends over 1, 6, 12, or 24 hours with min/max statistics
- **Session Info** — Displays baby's age, weight, monitoring duration, and alert count
- **Settings** — Configure Raspberry Pi IP address, baby age, and weight

## Architecture

The app communicates with a Raspberry Pi backend via HTTP REST API:

| Endpoint | Description |
|----------|-------------|
| `/latest_data` | Current vitals (bpm, spo2, temp) |
| `/one_hr_data` | 1-hour historical data |
| `/six_hr_data` | 6-hour historical data |
| `/twelve_hr_data` | 12-hour historical data |
| `/twenty_four_hr_data` | 24-hour historical data |

The live screen polls every 1.5 seconds; the history screen refreshes every 15 seconds.

## Prerequisites

### Install Flutter

1. Download and install the Flutter SDK from [flutter.dev/docs/get-started/install](https://docs.flutter.dev/get-started/install)
2. Add Flutter to your system PATH
3. Verify installation:
   ```bash
   flutter doctor
   ```
   Resolve any issues reported by `flutter doctor` before proceeding.

### Platform Requirements

- **Android**: Android Studio with Android SDK (API 21+)
- **iOS** (macOS only): Xcode 15+ with CocoaPods
- **Web**: Chrome browser
- **Windows**: Visual Studio 2022 with "Desktop development with C++" workload
- **Linux**: clang, cmake, ninja-build, pkg-config, libgtk-3-dev
- **macOS**: Xcode 15+

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `http` | ^1.2.0 | HTTP requests to Raspberry Pi backend |
| `fl_chart` | ^0.68.0 | Charting library |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

**Dart SDK**: ^3.11.5

## Getting Started

### 1. Clone the repository

```bash
cd App/BabyMonitorApp
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run the app

```bash
flutter run
```

To target a specific platform:

```bash
flutter run -d chrome       # Web
flutter run -d windows      # Windows desktop
flutter run -d macos        # macOS desktop
flutter run -d linux        # Linux desktop
flutter run -d <device_id>  # Connected Android/iOS device
```

List available devices with:

```bash
flutter devices
```

### 4. Configure the backend

Once the app is running, go to **Settings** and enter your Raspberry Pi's IP address (default: `http://10.85.160.236:5000`).

## Build for Release

```bash
flutter build apk        # Android APK
flutter build ios         # iOS (macOS only)
flutter build web         # Web deployment
flutter build windows     # Windows executable
flutter build macos       # macOS app
flutter build linux       # Linux binary
```

## Troubleshooting

- Run `flutter doctor` to diagnose environment issues
- Ensure the Raspberry Pi backend is running and reachable on the same network
- For Android, enable USB debugging or use a wireless connection
- For iOS, configure signing in Xcode before building
