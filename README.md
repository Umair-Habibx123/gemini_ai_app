# Gemini_AI_App

**Gemini_AI_App** is a Flutter-based mobile application that allows users to send text and image prompts to an AI, receiving creative and contextually relevant responses. The app leverages advanced AI models to generate text-based answers and image responses based on user input. Download APK [APK](https://github.com/Umair-Habibx123/gemini_ai_app/raw/master/APK/gemini_ai_app.apk)
---

## Features

- **Text-to-AI Communication**: Send text prompts to the AI and receive contextually relevant text-based responses.
- **Image Generation**: Upload or input image prompts and get text description based on your Image and description.
- **Intuitive UI**: Clean, user-friendly interface for easy interaction with AI.
- **AI Response Customization**: Tailor responses to your preferences with the app’s configuration options.
- **Real-Time Interaction**: Receive quick responses to your prompts, with AI working seamlessly in the background.

---

## Prerequisites

Before running the app, ensure that you have the following installed:

- **Flutter**: [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Dart**: Comes pre-installed with Flutter SDK
- **Android Studio / VS Code**: For a smooth development environment
- **Firebase (Optional)**: If you plan to use cloud functions or other Firebase features
- **Upgrade all dependency** : flutter pub upgrade --major-versions

---

## Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/Umair-Habibx123/gemini_ai_app
   cd Gemini_AI_App
   ```

2. **Install dependencies**

   Run the following command to install the required packages:

   ```bash
   flutter pub get
   ```

3. **Run the app**

   To run the app on an emulator or physical device:

   ```bash
   flutter run
   ```

---

## App Structure

Here’s a brief overview of the app structure:

```
lib/
├── screens/                  # Contains the UI for different app screens
│   ├── chatScreen.dart      # Home screen where users can interact with the app
├── widgets/                  # Contains reuseable widgets
│   ├── Appbar.dart
|   ├── ImagePreview.dart
│   ├── InputArea.dart
|   ├── MessageList.dart
├── DB/                            # Contain class for local chat storage
├── ├── SQLiteHelper.dart.dart
└── main.dart                         # Main entry point of the app
```

---

## Technologies Used

- **Flutter**: Cross-platform mobile app development
- **Gemini API** (or other AI service): For generating text and image prompts.
- **Provider / Riverpod**: State management (if used in the app).
- **Image Picker**: For image input.
- **HTTP / Dio**: For API calls and data fetching.

---

## API Integration

The app interacts with an external AI API (like OpenAI for GPT-3/4 or a similar service). You’ll need to obtain an API key from the AI service provider.

1. **API Key Setup**

   Obtain your API key from your service provider and add using .env it to your app’s environment configuration.

2. **Sending Text Prompts**

   The app sends text prompts to the AI and receives generated text. Use the following API endpoint:

   ```

   ```

3. **Sending Image Prompts**

   Upload image prompts to the API for text generation:

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- **Flutter**: For providing a cross-platform mobile development framework.
- **AI Service Provider**: For the powerful AI tools that drive the app's functionality.
- Special thanks to contributors and community support!