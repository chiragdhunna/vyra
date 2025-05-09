# 🤖 Vyra - Your Personal AI Assistant App

<p align="center">
  <img src="assets/vyra_logo.png" alt="Vyra Logo" width="250"/>
</p>

Vyra is a beautifully crafted AI-powered mobile companion designed to make everyday tasks delightful. Combining conversational intelligence, expressive visuals, voice interaction, and real-world awareness, Vyra brings an emotionally engaging assistant directly to your smartphone.

---

## 🚀 Features

### 💬 Intelligent Conversations

- Chat with Vyra using natural language powered by GPT-4 / GPT-4o
- Context-aware responses that feel more like a friend than a bot
- Supports both text and voice input/output

### 🎭 Animated Avatar

- Vyra comes to life with expressive animations
- Reactions tied to emotional tone and conversation mood
- Built using Rive for smooth, dynamic transitions

### 🗣️ Voice Interaction

- Real-time speech-to-text input
- High-quality TTS voice responses
- Hands-free experience with optional wake word

### 📸 Visual Intelligence

- Face and object detection via device camera
- Reactive behavior based on user presence or environment
- Privacy-friendly: all vision processing is done on-device

### 🧠 Smart Assistant Tools

- Reminder system with local notifications
- Live weather info
- Fun facts, motivational quotes, jokes, and more

---

## 📱 Screenshots

> Coming soon...

---

## 🧱 Tech Stack

| Component                 | Technology                          |
| ------------------------- | ----------------------------------- |
| **Framework**             | Flutter (iOS + Android)             |
| **AI API**                | OpenAI GPT-4 / GPT-4o               |
| **TTS**                   | flutter_tts / ElevenLabs (optional) |
| **Speech Input**          | Google Speech-to-Text               |
| **Animations**            | Rive / Lottie                       |
| **Face/Object Detection** | Google ML Kit / Firebase ML         |
| **Storage**               | Hive / SQLite / Firebase            |
| **State Mgmt**            | Riverpod / BLoC                     |
| **Notifications**         | flutter_local_notifications         |
| **Camera**                | camera, google_mlkit                |
| **Wake Word**             | Porcupine / Snowboy (native bridge) |

---

## 🎨 Architecture & Modules

### 🎭 Animated Avatar (Vyra's Face)

- Built using `rive` or `lottie`
- Emotions: happy, thinking, sad, excited, etc.
- Sentiment-mapped responses via OpenAI or local parsing

### 🧠 AI Engine (Chat Layer)

- GPT-4/GPT-4o via OpenAI API
- Streaming conversation + emotion tagging
- Custom personality via system prompt

### 🗣️ Voice Input / Output

- `speech_to_text` for capturing voice
- `flutter_tts` or ElevenLabs API for emotional voice feedback
- (Optional) wake word activation via `porcupine` or native call

### 📸 Vision Features

- `google_mlkit_face_detection` & `object_detection`
- Real-time camera access via `camera`
- Fun behavior triggers based on detected face or object

### 🛠️ Assistant Tools

- Local notifications for reminders via `flutter_local_notifications`
- Weather via OpenWeatherMap API
- Daily quotes, facts, jokes via public APIs

---

## 🧭 Folder Structure

```bash
lib/
├── core/            # Themes, constants, utils
├── features/
│   ├── chat/        # Conversational logic + UI
│   ├── avatar/      # Animated assistant face
│   ├── voice/       # Speech-to-text and TTS
│   ├── vision/      # Camera-based AI
│   └── assistant/   # Weather, reminders, quotes, etc
├── shared/          # Shared components/widgets
├── services/        # API clients, storage
└── main.dart
```

---

## 🏗️ Flavors & Environments

Vyra supports multiple build flavors for different environments: **dev**, **staging**, and **prod**.

### Dart Entrypoints

- `lib/main_dev.dart` &rarr; Development environment
- `lib/main_staging.dart` &rarr; Staging environment
- `lib/main_prod.dart` &rarr; Production environment

### Android Setup

Product flavors are defined in [`android/app/build.gradle.kts`](android/app/build.gradle.kts):

```kotlin
flavorDimensions += "env"
productFlavors {
    create("dev") {
        dimension = "env"
        applicationIdSuffix = ".dev"
        versionNameSuffix = "-dev"
    }
    create("staging") {
        dimension = "env"
        applicationIdSuffix = ".staging"
        versionNameSuffix = "-staging"
    }
    create("prod") {
        dimension = "env"
        // No suffix for prod
    }
}
```

### Running Flavors

Use the following commands to run a specific flavor:

```bash
# Development
flutter run --flavor dev -t lib/main_dev.dart

# Staging
flutter run --flavor staging -t lib/main_staging.dart

# Production
flutter run --flavor prod -t lib/main_prod.dart
```

### iOS Setup

- Duplicate schemes in Xcode for each flavor (dev, staging, prod).
- Set the correct Dart entrypoint for each scheme.

---

## 📦 Installation

```bash
git clone https://github.com/your-username/vyra_ai_assistant.git
cd vyra_ai_assistant
flutter pub get
flutter run
```

Make sure to:

- Add your `OpenAI` API key in a secure place (e.g., dotenv)
- Configure TTS and ML Kit permissions in platform code

---

## 📅 Roadmap

- [x] Chat interface with GPT-4
- [x] Animated avatar + emotion mapping
- [x] Voice interaction pipeline
- [ ] Visual interaction (face/object detection)
- [ ] Assistant plugins (weather, reminders)
- [ ] Onboarding & settings
- [ ] Release on Play Store / App Store

---

## 🤝 Contribution

Pull requests are welcome. For major changes, please open an issue first.

If you're interested in contributing animations, voice packs, or new assistant modules—reach out!

---

Vyra is built with ❤️ to bring humanlike AI presence to mobile experiences.
