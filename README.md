# 🤖 Vyra - Your Personal AI Assistant App

<p align="center">
  <img src="assets/vyra_logo.png" alt="Vyra Logo" width="250"/>
</p>

Vyra is a beautifully crafted AI-powered mobile companion designed to make everyday tasks delightful. Combining conversational intelligence, expressive visuals, voice interaction, and real-world awareness, Vyra brings an emotionally engaging assistant directly to your smartphone.

> **Powered by Google Gemini.** Vyra's animated face is hand-built with Flutter's own animation framework (`CustomPainter` + `AnimationController`) — no Rive, no Lottie, no asset files.

---

## 🚀 Features

### 💬 Intelligent Conversations

- Chat with Vyra using natural language, powered by **Google Gemini**
- Multi-turn, context-aware conversations that persist across restarts
- Supports both text and voice input/output

### 🎭 Animated Avatar

- A glowing, living orb-face that blinks, emotes, talks and reacts
- Emotions (happy, excited, thinking, sad, surprised, caring, neutral) are driven by Gemini via hidden `[emotion: …]` tags and crossfade smoothly
- **100% hand-animated** in Flutter — a `Ticker` clock drives a `CustomPainter`

### 🗣️ Voice Interaction

- Real-time speech-to-text input (`speech_to_text`)
- Natural text-to-speech replies (`flutter_tts`) — Vyra's mouth moves while she talks
- A hand-painted live waveform visualizes your voice

### 📸 Visual Intelligence

- Face detection via the device camera (Google ML Kit)
- Vyra reacts to your presence and your smile
- Privacy-friendly: **all vision processing happens on-device**

### 🧠 Smart Assistant Tools

- Reminder system with local notifications
- Live weather (OpenWeatherMap + geolocation)
- Inspirational quotes, jokes and fun facts from free public APIs

---

## 🧱 Tech Stack

| Component                 | Technology                                |
| ------------------------- | ----------------------------------------- |
| **Framework**             | Flutter (iOS + Android)                   |
| **AI API**                | Google Gemini (`google_generative_ai`)    |
| **State Management**      | Riverpod (`flutter_riverpod`)             |
| **TTS**                   | `flutter_tts`                             |
| **Speech Input**          | `speech_to_text`                          |
| **Animations**            | Custom Flutter `CustomPainter` (no Rive)  |
| **Face Detection**        | `google_mlkit_face_detection` + `camera`  |
| **Storage**               | Hive + `shared_preferences`               |
| **Notifications**         | `flutter_local_notifications` + `timezone`|
| **Weather / Location**    | OpenWeatherMap + `geolocator`             |
| **Config**                | `flutter_dotenv` (+ optional Firebase)    |

---

## 🎨 Architecture & Modules

### 🎭 Animated Avatar (Vyra's Face)

- Built with `CustomPainter` + a `Ticker`-based clock — no animation packages
- Emotions map to Gemini's `[emotion: …]` tags; the painter crossfades eyes, brows and mouth
- Layered motion: idle breathing, blinking, listening pulse, talking mouth, "thinking" dots, sound-wave ripples and ambient particles

### 🧠 AI Engine (Chat Layer)

- Google Gemini via the official `google_generative_ai` SDK
- A single multi-turn chat session with a custom personality system prompt
- Replies are parsed into `(text, emotion)` so the face reacts in sync
- Degrades gracefully with a friendly message if no API key is present

### 🗣️ Voice Input / Output

- `speech_to_text` for capturing voice (with live sound levels → avatar)
- `flutter_tts` for spoken replies; the avatar mouths along while speaking

### 📸 Vision Features

- `google_mlkit_face_detection` + `camera` with the standard on-device pipeline
- Reactions triggered by detected faces and smiles — nothing leaves the device

### 🛠️ Assistant Tools

- Local notifications for reminders via `flutter_local_notifications`
- Weather via OpenWeatherMap
- Daily quotes, facts and jokes via public APIs

---

## 🧭 Folder Structure

```bash
lib/
├── core/                 # Config (env, flavors), theme, constants, utils, shared providers
├── features/
│   ├── avatar/           # Hand-animated face (painter, emotions, provider)
│   ├── chat/             # Conversational logic + UI
│   ├── voice/            # Speech-to-text, text-to-speech, waveform
│   ├── vision/           # Camera-based face detection
│   ├── assistant/        # Weather, reminders, quotes/jokes/facts
│   ├── home/             # Home hub + bottom-nav shell
│   ├── onboarding/       # First-run flow
│   └── settings/         # Preferences
├── shared/               # Reusable widgets (gradient bg, glass card, buttons)
├── services/             # Gemini, voice, vision, storage, notifications
├── app.dart              # Root MaterialApp
└── main.dart             # Bootstrap + flavor entrypoint
```

---

## 📦 Installation

```bash
git clone https://github.com/chiragdhunna/vyra.git
cd vyra

# 1. Create your environment file and add your keys
cp .env.example .env
#   then edit .env and set at least GEMINI_API_KEY

# 2. Install dependencies and run
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart
```

### Environment variables (`.env`)

| Key                   | Required | Notes                                                        |
| --------------------- | -------- | ------------------------------------------------------------ |
| `GEMINI_API_KEY`      | ✅       | Get one at https://aistudio.google.com/app/apikey            |
| `GEMINI_MODEL`        | optional | Defaults to `gemini-1.5-flash`                               |
| `OPENWEATHER_API_KEY` | optional | Enables live weather (https://openweathermap.org/api)        |
| `FIREBASE_*`          | optional | Vyra runs fine without Firebase                              |

> `.env` is git-ignored. The app still runs without keys — features that need them show a friendly prompt instead of crashing.

### Permissions

Camera, microphone, speech recognition, location and notification permissions are already declared in `AndroidManifest.xml` and `Info.plist`, and are requested at runtime when first used.

---

## 🏗️ Flavors & Environments

Vyra supports **dev**, **staging**, and **prod** flavors.

```bash
flutter run --flavor dev     -t lib/main_dev.dart
flutter run --flavor staging -t lib/main_staging.dart
flutter run --flavor prod    -t lib/main_prod.dart
```

For iOS, duplicate the Xcode schemes per flavor and point each at the matching Dart entrypoint.

---

## 📅 Roadmap

- [x] Chat interface powered by Gemini
- [x] Animated avatar + emotion mapping (hand-built, no Rive)
- [x] Voice interaction pipeline (STT + TTS)
- [x] Visual interaction (on-device face detection)
- [x] Assistant tools (weather, reminders, quotes/jokes/facts)
- [x] Onboarding & settings
- [ ] Object detection & richer scene awareness
- [ ] Wake-word activation
- [ ] Release on Play Store / App Store

---

## 🤝 Contribution

Pull requests are welcome. For major changes, please open an issue first.

If you're interested in contributing new emotions, voice packs, or assistant modules—reach out!

---

Vyra is built with ❤️ to bring humanlike AI presence to mobile experiences.
