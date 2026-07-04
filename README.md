# 🤖 Vyra — Your Personal AI Companion

<p align="center">
  <img src="assets/vyra_logo.png" alt="Vyra Logo" width="220"/>
</p>

<p align="center">
  <a href="https://github.com/chiragdhunna/vyra/actions/workflows/android-ci-cd.yml">
    <img src="https://github.com/chiragdhunna/vyra/actions/workflows/android-ci-cd.yml/badge.svg" alt="Android CI/CD"/>
  </a>
  <img src="https://img.shields.io/badge/Flutter-3.29-02569B?logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/AI-Google%20Gemini-8E75FF?logo=google" alt="Google Gemini"/>
  <img src="https://img.shields.io/badge/State-Riverpod-0553B1" alt="Riverpod"/>
</p>

**Vyra** is a beautifully crafted, emotionally engaging AI companion for mobile. She chats like a close friend, shows feelings through a living animated face, listens and talks back hands‑free, sees you through the camera, and helps with everyday things — weather, reminders, and a little delight.

> **Powered by Google Gemini — or your own local model.** With the companion backend ([vyra-backend](https://github.com/chiragdhunna/vyra-backend)) on your Wi‑Fi, Vyra's brain can be **Ollama (fully local/private), Gemini, or any OpenAI‑compatible model**, chosen by the backend's `.env`. Vyra's animated face is **hand‑built** with Flutter's own animation framework (`CustomPainter` + `AnimationController`) — no Rive, no Lottie, no asset files. Light **and** dark themes, multi‑conversation history, and hands‑free voice are all built in.

---

## 🛋️ Companion mode (new home screen)

Vyra now opens straight into a single full‑screen **companion view**: her animated face, a status chip, and a mute button. No tabs, no chat bubbles — the phone sits on your desk and she's simply *there*. The camera is on for awareness (presence + smile, processed on‑device) but **you never see yourself — only her**. The classic screens (chat, history, tools) live behind the widgets icon, top‑right.

It runs in one of three modes, picked automatically at startup:

| Mode | When | What you get |
| --- | --- | --- |
| **Backend live** | `VYRA_BACKEND_URL` set, backend has Whisper | Continuous mic streaming to [vyra-backend](https://github.com/chiragdhunna/vyra-backend): server VAD decides when you finished, you can **interrupt her mid‑sentence** (barge‑in), and she greets/re‑engages proactively. |
| **Backend hybrid** | `VYRA_BACKEND_URL` set, no server STT | On‑device turn‑based ears, but the backend's brain (Ollama/cloud) + server‑side proactivity. |
| **Standalone** | no backend configured | The original on‑device loop talking to Gemini directly (needs `GEMINI_API_KEY`). |

Setup for backend modes: run vyra-backend on a computer, phone on the **same Wi‑Fi**, then set `VYRA_BACKEND_URL=http://<computer-LAN-IP>:8000` in this app's `.env`. API keys stay on the computer — the phone never ships one.

---

## ✨ Highlights

- 🧠 **Conversational AI** powered by Google Gemini with a warm, witty personality.
- 🎭 **Hand‑animated avatar** with 9 emotions (including teary `cry` and a new `angry`) that react to the conversation in real time.
- 🗣️ **Hands‑free voice mode** — a turn‑based "listen → reply → listen" loop, like talking to a friend.
- 📸 **On‑device vision** — Vyra notices your presence and your smile (nothing leaves the phone).
- 💬 **Saved conversations** — start new chats, browse history, and pick any past chat back up.
- 🌗 **Light & dark themes** that switch live (Light / Dark / Auto) and retint the whole app instantly.
- 🌦️ **Assistant tools** — live weather, reminders with notifications, and quotes / jokes / facts.
- 🔐 **Robust runtime permissions** — requests are serialized so dialogs never collide.

---

## 🚀 Features

### 💬 Intelligent Conversations
- Natural, multi‑turn chat powered by **Google Gemini** (`google_generative_ai`).
- A custom personality system prompt makes Vyra warm, curious and proactive — she asks questions back.
- **Multiple saved conversations**: each chat is stored separately, titled from your first message, with a last‑message preview and timestamp.
- **Chat History screen** to browse, reopen, or delete past conversations. Starting a new chat is non‑destructive — the old one is kept.
- Conversations persist across restarts (Hive); legacy single‑thread history is migrated automatically on upgrade.
- Degrades gracefully: with no API key, Vyra shows a friendly prompt instead of crashing.

### 🎭 Animated Avatar (Vyra's Face)
- A glowing, living orb‑face that blinks, breathes, emotes, talks and reacts — **100% hand‑animated** in Flutter.
- A `Ticker`‑driven clock feeds a `CustomPainter`; facial parameters (eyes, brows, mouth, tears) **lerp** between states for smooth crossfades.
- **9 emotions** — `neutral`, `happy`, `excited`, `thinking`, `sad`, `surprised`, `caring`, `cry`, `angry` — chosen by Gemini via hidden `[emotion: …]` tags and parsed out before display.
- Layered motion: idle breathing, blinking, listening amplitude pulse, talking mouth, "thinking" dots, sound‑wave ripples, ambient particles, and falling tears for `cry`.
- She reacts honestly to how she's treated — kindness brings `happy`/`excited`, hard moments bring `caring`, genuine hurt can bring `sad`/`cry`.

### 🗣️ Voice Interaction (Hands‑Free)
- Real‑time speech‑to‑text (`speech_to_text`) and natural text‑to‑speech (`flutter_tts`) — the mouth moves while she speaks.
- **Turn‑based hands‑free loop** on the Live screen: the mic opens for your turn, ends on your pause, Vyra replies, then the mic reopens automatically for the next turn — no tapping.
- A gentle re‑engagement nudge after a lull (capped, so she never nags), and a pause/resume mic button.
- A hand‑painted live **waveform** visualizes your voice; mic levels also drive the avatar.

> ℹ️ Vyra uses the device's native on‑device speech recognizer, which works in turns (one speaker at a time). True barge‑in / interrupt‑anytime voice would require a streaming‑ASR backend — see the Roadmap.

### 📸 Visual Intelligence (Live)
- Camera face detection via **Google ML Kit** (`google_mlkit_face_detection` + `camera`).
- Vyra reacts to your **presence** and your **smile**, driving the avatar's emotion — the camera powers awareness while the animated character is what you see.
- **Privacy‑friendly:** all vision processing happens **on‑device**; frames never leave the phone. The camera is released promptly when you leave the screen.

### 🧠 Smart Assistant Tools
- **Live weather** via OpenWeatherMap + `geolocator` (with a cached‑location fast path and bounded lookups so it never hangs).
- **Reminders** with scheduled local notifications (`flutter_local_notifications` + `timezone`).
- **Quotes, jokes and fun facts** from free public APIs.

### 🌗 Theming
- **Dark‑first** (Vyra glows against a deep‑violet canvas) with a **fully realized light theme**.
- Switch **Light / Dark / Auto** in Settings — the change applies **live across the whole app**, no restart, and "Auto" follows the OS.
- Brightness‑aware design tokens keep surfaces, gradients and typography correct in both modes.

### 🧭 Onboarding & Settings
- A friendly first‑run flow.
- Settings for your name, voice/TTS toggles, speech rate, theme mode, and clearing chat history.

---

## 🧱 Tech Stack

| Component              | Technology                                   |
| ---------------------- | -------------------------------------------- |
| **Framework**          | Flutter 3.29 (Android + iOS), Dart `^3.7`    |
| **AI engine**          | Google Gemini (`google_generative_ai`)       |
| **State management**   | Riverpod (`flutter_riverpod`, `StateNotifier`)|
| **Animations**         | Hand‑built `CustomPainter` + `Ticker` (no Rive/Lottie) |
| **Speech input**       | `speech_to_text` (turn‑based) · `record` PCM streaming (companion live mode) |
| **Speech output**      | `flutter_tts`                                |
| **Vision**             | `google_mlkit_face_detection` + `camera`     |
| **Backend link**       | `web_socket_channel` (realtime) + `http` (chat) → [vyra-backend](https://github.com/chiragdhunna/vyra-backend) |
| **Storage**            | Hive + `shared_preferences`                  |
| **Notifications**      | `flutter_local_notifications` + `timezone`   |
| **Weather / location** | OpenWeatherMap + `geolocator`                |
| **Permissions**        | `permission_handler` (serialized)            |
| **Config**             | `flutter_dotenv` (+ optional `firebase_core`)|
| **Fonts / utils**      | `google_fonts`, `intl`, `uuid`, `equatable`  |

---

## 🏛️ Architecture

Vyra follows a **feature‑first** structure with a thin **services** layer and **Riverpod** for state.

- **Feature modules** (`lib/features/*`) each own their UI (`presentation/`), state (`providers/`) and, where relevant, data/models. State is held in `StateNotifier`s exposed via `StateNotifierProvider`.
- **Services** (`lib/services/*`) wrap the platform/SDK plumbing — Gemini, STT, TTS, ML Kit face detection, Hive storage and notifications — behind small, testable singletons.
- **Core** (`lib/core/*`) holds cross‑cutting concerns: environment/flavor config, theme tokens, app constants (including Vyra's personality prompt), shared providers and the permission queue.
- **The avatar is the integration point:** chat, voice and vision all push an `emotion` + `activity` to the `AvatarController`, and the painter renders the result — so Vyra's face stays in sync with what she's doing.

### 🔐 Permission model
Vyra requests **microphone** (voice) and **location** (weather) at runtime. Because every tab is built eagerly in the home `IndexedStack`, those requests could fire simultaneously — and Android only shows **one** permission dialog at a time, which dropped a prompt and left the loser's request hanging. A small **`PermissionService`** serializes all requests through a single queue so each dialog appears in turn and each request resolves cleanly.

### 🤖 AI engine details
- A single multi‑turn Gemini session per active conversation, seeded with the conversation's history.
- The system prompt (in `core/constants/app_constants.dart`) defines Vyra's voice and instructs the model to end every reply with a hidden `[emotion: X]` tag; replies are parsed into `(text, emotion)` so the avatar reacts.
- Default model: **`gemini-2.5-flash`** (fast, free‑tier eligible). Older `gemini-1.5-flash` / `gemini-2.0-flash` were retired by Google.

---

## 🗂️ Project Structure

```text
lib/
├── core/
│   ├── config/          # env.dart (.env access), flavor_config.dart
│   ├── constants/       # app_constants.dart (Vyra personality prompt), api_constants.dart
│   ├── providers/       # settings_provider.dart
│   ├── services/        # permission_service.dart (serialized permission queue)
│   ├── theme/           # app_colors.dart (brightness‑aware), app_theme.dart, app_text_styles.dart
│   └── utils/           # app_logger.dart, extensions.dart
├── features/
│   ├── avatar/          # avatar_emotion.dart (9 emotions incl. cry, angry), avatar_painter.dart, provider
│   ├── chat/            # chat_message + chat_conversation models, chat_provider,
│   │                    # chat_screen, chat_history_screen, message/typing/input widgets
│   ├── voice/           # voice_provider (STT/TTS bridge), voice_wave widget
│   ├── vision/          # vision_provider (camera + ML Kit), vision_screen (Live), overlay painter
│   ├── assistant/       # weather_api + fun_content_api, providers, assistant_screen, cards
│   ├── home/            # home_screen (bottom‑nav shell), home_hub_screen, quick‑action cards
│   ├── onboarding/      # first‑run flow
│   └── settings/        # preferences (name, voice, theme, clear history)
├── services/
│   ├── ai/              # gemini_service.dart
│   ├── voice/           # stt_service.dart, tts_service.dart
│   ├── vision/          # face_detection_service.dart
│   ├── storage/         # storage_service.dart (Hive + shared_preferences)
│   ├── notifications/   # notification_service.dart
│   └── service_providers.dart
├── shared/widgets/      # gradient background, glass card, primary button, flavor banner
├── app.dart             # Root MaterialApp (theme + brightness wiring)
├── main.dart            # Shared bootstrap (mainCommon)
├── main_dev.dart        # Dev flavor entrypoint
├── main_staging.dart    # Staging flavor entrypoint
└── main_prod.dart       # Prod flavor entrypoint
```

---

## 🏁 Getting Started

### Prerequisites
- Flutter **3.29.x** and Dart `^3.7`
- Android SDK (minSdk **24**) / Xcode for iOS
- A Google **Gemini** API key

### Setup

```bash
# 1. Clone
git clone https://github.com/chiragdhunna/vyra.git
cd vyra

# 2. Configure environment
cp .env.example .env
#    then edit .env and set at least GEMINI_API_KEY

# 3. Install dependencies
flutter pub get

# 4. Run (dev flavor)
flutter run --flavor dev -t lib/main_dev.dart
```

### Environment variables (`.env`)

| Key                   | Required | Notes                                                            |
| --------------------- | :------: | ---------------------------------------------------------------- |
| `VYRA_BACKEND_URL`    |    —     | `http://<computer-LAN-IP>:8000` running [vyra-backend](https://github.com/chiragdhunna/vyra-backend). When set, Vyra's brain lives there (Ollama or cloud) and no key is needed on the phone. |
| `VYRA_BACKEND_API_KEY`|    —     | Only if the backend sets `VYRA_API_KEY`                          |
| `GEMINI_API_KEY`      | standalone | Get one at <https://aistudio.google.com/app/apikey> — required only without a backend |
| `GEMINI_MODEL`        |    —     | Defaults to `gemini-2.5-flash` (must be a current model)         |
| `OPENWEATHER_API_KEY` |    —     | Enables live weather (<https://openweathermap.org/api>)          |
| `FIREBASE_*`          |    —     | Optional; Vyra runs fine without Firebase                        |

> `.env` is git‑ignored and bundled as an asset. The app still runs without optional keys — features that need them show a friendly prompt instead of failing.

---

## 🧩 Flavors & Environments

Vyra ships **dev**, **staging** and **prod** flavors (Gradle `env` dimension; `.dev` / `.staging` application‑id suffixes), each with its own Dart entrypoint:

```bash
flutter run --flavor dev     -t lib/main_dev.dart
flutter run --flavor staging -t lib/main_staging.dart
flutter run --flavor prod    -t lib/main_prod.dart
```

Production APK (what CI ships):

```bash
flutter build apk --flavor prod -t lib/main_prod.dart
```

> For iOS, duplicate the Xcode schemes per flavor and point each at the matching Dart entrypoint.

---

## 🔁 CI/CD

A single workflow — **`.github/workflows/android-ci-cd.yml`** — runs on pushes to `main`/`develop`, `v*` tags, pull requests, and manual dispatch (with a `patch`/`minor`/`major` version‑bump input):

1. **`test`** — `flutter analyze --no-fatal-infos` + `flutter test` (Flutter 3.29.2). Style‑only lints don't fail the build; real warnings/errors do.
2. **`build-internal`** — builds the prod APK and distributes it via **Fastlane → Firebase App Distribution**, and publishes an "Internal Build" GitHub pre‑release from `main`.
3. **`build-prod`** — reuses the built APK, auto‑computes the next `vX.Y.Z` tag (or uses the pushed tag), and publishes a production GitHub Release.

### Required GitHub secrets

| Secret | Purpose |
| ------ | ------- |
| `GEMINI_API_KEY` | Gemini key baked into the CI `.env` |
| `OPENWEATHER_API_KEY` | Weather key (optional) |
| `FIREBASE_ANDROID_API_KEY`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_ANDROID_MESSAGING_SENDER_ID`, `FIREBASE_ANDROID_PROJECT_ID`, `FIREBASE_ANDROID_STORAGE_BUCKET` | Firebase config for the build |
| `FIREBASE_SERVICE_ACCOUNT` | Service‑account JSON for Firebase App Distribution |

`GITHUB_TOKEN` is provided automatically by Actions for creating releases.

---

## 🔐 Permissions

Declared in `AndroidManifest.xml` (and iOS `Info.plist`) and requested at runtime, serialized through `PermissionService`:

| Permission | Used for |
| ---------- | -------- |
| Microphone | Voice input (speech‑to‑text) |
| Camera | On‑device face detection (Live) |
| Location (fine/coarse) | Live weather |
| Notifications | Reminders |

If a permission is permanently denied, Vyra shows an actionable message pointing to system Settings rather than failing silently.

---

## 🧪 Quality

```bash
flutter analyze --no-fatal-infos   # static analysis (matches CI)
flutter test                       # unit/widget tests
```

---

## 📅 Roadmap

- [x] Gemini‑powered chat with persistent, **multi‑conversation history**
- [x] Hand‑built animated avatar + emotion mapping (8 emotions incl. `cry`)
- [x] Voice pipeline (STT + TTS) with **turn‑based hands‑free** mode
- [x] On‑device vision (face/smile detection) with prompt camera release
- [x] Assistant tools (weather, reminders, quotes/jokes/facts)
- [x] **Light & dark themes** with live switching
- [x] Onboarding & settings
- [x] Streaming‑ASR backend for true interrupt‑anytime voice — via [vyra-backend](https://github.com/chiragdhunna/vyra-backend) companion live mode
- [ ] Object detection & richer scene awareness
- [ ] Wake‑word activation
- [ ] Play Store / App Store release

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you'd like to change. New emotions, voice packs, and assistant modules are especially appreciated.

---

<p align="center"><em>Vyra is built with ❤️ to bring a warm, humanlike AI presence to mobile.</em></p>
