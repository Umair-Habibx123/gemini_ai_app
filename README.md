# 🤖 Gemini AI App

### Chat with AI using text and images — powered by Google Gemini

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Gemini](https://img.shields.io/badge/Gemini%20AI-Google-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev)
[![Android](https://img.shields.io/badge/Android-API%2021+-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://android.com)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

[⬇️ Download APK](https://github.com/Umair-Habibx123/gemini_ai_app/releases/download/v1.1/gemini_ai_app.apk) • [🐛 Report Bug](https://github.com/Umair-Habibx123/gemini_ai_app/issues) • [✨ Request Feature](https://github.com/Umair-Habibx123/gemini_ai_app/issues)

</div>

---

## 📖 About

**Gemini AI App** is a Flutter-based mobile application that lets users send text and image prompts to Google's Gemini AI, receiving creative and contextually relevant responses in real time. Built with a clean, intuitive UI for seamless AI interaction on Android.

---

## ✨ Features

- 💬 **Text Prompts** — Send any text prompt and get intelligent AI-generated responses
- 🖼️ **Image Understanding** — Upload an image and get a text description or answer based on it
- 🗃️ **Local Chat History** — Conversations saved locally using SQLite
- ⚡ **Real-Time Responses** — Fast, seamless AI interaction in the background
- 🎨 **Clean UI** — Intuitive and minimal interface for smooth user experience

---

## 📲 Download

| Platform | Download |
|---|---|
| Android (APK) | [⬇️ Download APK](https://github.com/Umair-Habibx123/gemini_ai_app/releases/download/v1.1/gemini_ai_app.apk) |

> ℹ️ Enable **"Install from Unknown Sources"** in Android settings before installing.

All releases → [GitHub Releases](https://github.com/Umair-Habibx123/gemini_ai_app/releases)

---

## 🛠️ Built With

- [Flutter](https://flutter.dev/) — Cross-platform UI framework
- [Dart](https://dart.dev/) — Programming language
- [Gemini API](https://ai.google.dev/) — Google's AI model for text & image understanding
- [SQLite](https://pub.dev/packages/sqflite) — Local chat history storage
- [Image Picker](https://pub.dev/packages/image_picker) — Image input from camera/gallery
- [HTTP](https://pub.dev/packages/http) — API requests

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or higher)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/)
- Android device or emulator (API 21+)
- [Gemini API Key](https://ai.google.dev/) (free)

Check your Flutter setup:
```bash
flutter doctor
```

---

### Installation

**1. Clone the repository**
```bash
git clone https://github.com/Umair-Habibx123/gemini_ai_app
cd gemini_ai_app
```

**2. Install dependencies**
```bash
flutter pub get
```

**3. Upgrade all packages (optional)**
```bash
flutter pub upgrade --major-versions
```

**4. Add your Gemini API Key**

Create a `.env` file in the project root:
```env
GEMINI_API_KEY=your_api_key_here
```

Or add it directly in the config file if `.env` is not set up:
```dart
const String geminiApiKey = 'YOUR_API_KEY_HERE';
```

> Get your free API key at [Google AI Studio](https://aistudio.google.com/app/apikey)

**5. Run the app**
```bash
# Check connected devices
flutter devices

# Run on your device
flutter run -d <device_id>
```

---

## 📁 Project Structure

```
gemini_ai_app/
├── lib/
│   ├── main.dart                   # App entry point
│   ├── screens/
│   │   └── chatScreen.dart         # Main chat screen
│   ├── widgets/
│   │   ├── Appbar.dart             # Custom app bar
│   │   ├── ImagePreview.dart       # Image preview widget
│   │   ├── InputArea.dart          # Text/image input area
│   │   └── MessageList.dart        # Chat message list
│   └── DB/
│       └── SQLiteHelper.dart       # Local chat storage (SQLite)
├── android/                        # Android-specific config
├── assets/                         # Images, fonts, etc.
└── pubspec.yaml                    # Dependencies & metadata
```

---

## 📦 Build APK

```bash
# Debug build (for testing)
flutter build apk --debug

# Release build (for distribution)
flutter build apk --release
```

Output:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🌐 API Reference

This app uses the [Gemini API](https://ai.google.dev/) by Google.

| Model | Use Case |
|---|---|
| `gemini-1.5-flash` | Fast text responses |
| `gemini-1.5-pro` | Advanced reasoning & image understanding |

**Free tier:** Available via [Google AI Studio](https://aistudio.google.com/) with generous limits for development.

---

## 🤝 Contributing

Contributions are welcome!

1. Fork the repository
2. Create a feature branch
```bash
git checkout -b feature/AmazingFeature
```
3. Commit your changes
```bash
git commit -m "Add AmazingFeature"
```
4. Push to the branch
```bash
git push origin feature/AmazingFeature
```
5. Open a Pull Request

---

## 🐛 Issues

Found a bug or have a suggestion? [Open an issue](https://github.com/Umair-Habibx123/gemini_ai_app/issues)

---

## 📄 License

This project is open-source under the **MIT License**. See the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Google Gemini](https://ai.google.dev/) — For the powerful AI API
- [Flutter](https://flutter.dev/) — For the amazing cross-platform framework
- Community contributors and supporters