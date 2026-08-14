# 🎵 Kukku - Modern Music Streaming App

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

**An ad-free, high-performance music streaming application built with Flutter featuring real-time regional language filters, YouTube stream integration, background playback, and persistent library management.**

</div>

---

## ✨ Features

- 🌐 **Dynamic Regional Language Filtering**:
  - Instant one-tap filtering across **Malayalam, Tamil, Hindi, Telugu, Kannada, Punjabi, English**, and global **Trending**.
  - In-memory caching for zero latency when switching between languages.

- 🎬 **Section-Wise Categorized Content**:
  - **Trending Hits**: Poster cards with one-tap quick play.
  - **Movie Soundtracks & OSTs**: Curated film hits and soundtrack collections.
  - **Popular Artists**: Circular artist avatar strip with one-tap discography search.
  - **Essential Melodies & Top Picks**: Complete tracklist with duration, view counts, and context menus.
  - **"Play All" Queueing**: Instantly queue and play any entire section with one tap.

- 🎧 **Rich Audio Playback Engine**:
  - Powered by `just_audio` and `audio_service`.
  - Android notification bar & lock screen media controls with album artwork.
  - Background audio playback with queue support.
  - Failover proxy fallback for 100% reliable streaming.

- 📜 **History & Library Management**:
  - Reactive **Recently Played** shelf.
  - One-tap **"Clear All"** with modal confirmation.
  - Per-track **"Remove from History"** context menu.
  - Offline local persistence powered by **Hive**.

- 🔍 **Instant Search & Autocomplete**:
  - Debounced real-time search for tracks, artists, and soundtrack albums.
  - Search history tracking with quick re-querying.

- 🎨 **Glassmorphism & Neon Dark Theme**:
  - Beautiful deep navy/black aesthetic with vibrant violet-indigo gradients.
  - Animated mini-player bar and expandible full-screen player with lyrics view.

---

## 🛠️ Tech Stack & Architecture

- **Framework**: [Flutter](https://flutter.dev) (Dart 3.x)
- **State Management**: [GetX](https://pub.dev/packages/get)
- **Audio Engine**: [`just_audio`](https://pub.dev/packages/just_audio) + [`audio_service`](https://pub.dev/packages/audio_service)
- **Data Engine**: [`youtube_explode_dart`](https://github.com/anandnet/youtube_explode_dart) with signature deciphering
- **Local Storage**: [`hive`](https://pub.dev/packages/hive) & [`hive_flutter`](https://pub.dev/packages/hive_flutter)
- **Image Caching**: [`cached_network_image`](https://pub.dev/packages/cached_network_image)

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24.0 or later)
- Android Studio / VS Code
- Android Device or Emulator (Android 8.0+ / API 26+)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/abhi963007/Kukku-Music.git
   cd Kukku-Music
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on connected Android device:**
   ```bash
   flutter run
   ```

4. **Build APK:**
   ```bash
   flutter build apk --release
   ```

---

## 📂 Project Structure

```
lib/
├── controllers/          # GetX State Controllers
│   ├── player_controller.dart
│   ├── search_controller.dart
│   └── theme_controller.dart
├── models/               # Data Models (Song, Playlist, Album)
├── services/             # Background Audio & Music Services
│   ├── audio_handler.dart
│   ├── music_service.dart
│   └── piped_stream_service.dart
├── ui/                   # UI Screens & Widgets
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── now_playing_screen.dart
│   │   ├── search_screen.dart
│   │   └── library_screen.dart
│   ├── theme/
│   └── widgets/
└── main.dart             # App Entry Point & Dependency Injection
```

---

## 📄 License
This project is licensed under the MIT License.
