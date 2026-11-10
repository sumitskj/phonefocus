# PhoneFocus

PhoneFocus is a local macOS app that reminds you to put your phone away while you wait for a Codex response. It uses the camera to look for a phone near the primary person in the frame. After more than five seconds of continuous detection, it repeats a spoken reminder or your chosen audio file.

The app is built for **Apple Silicon Macs running macOS 14 or later**. It processes camera frames on the Mac and does not record or upload video.

## Features

- Starts camera monitoring during a **local Codex** turn and stops when that turn ends or is interrupted.
- Offers a manual mode and a pause button for automatic monitoring.
- Repeats an alert after a phone has been detected for more than five seconds.
- Lets you choose an audio file and snooze an active alert for five minutes. Monitoring continues during snooze, so the alert resumes if the phone is still present afterward.
- Prefers an iPhone Continuity Camera when available, with a picker for other cameras. The preview shows the full frame.
- Keeps working from the menu bar when the main window is closed.

## Build and run

You need macOS 14+, Apple Command Line Tools (`xcode-select --install`), and internet access for the first build.

```sh
./build.sh
open PhoneFocus.app
```

The build script downloads Apple's `YOLOv3FP16.mlmodel` from the [Core ML model gallery](https://developer.apple.com/machine-learning/models/), compiles the Swift app, bundles the model and fallback sound, and signs the app locally. The 118 MB model and generated app are excluded from Git by `.gitignore`.

When you first start monitoring, macOS asks for camera permission. No microphone permission is needed. Use **Choose audio…** to select an MP3, WAV, AIFF, or other format supported by `AVAudioPlayer`. Without a selected file, PhoneFocus repeats a macOS speech reminder; if speech cannot start, it repeats the bundled chime.

## Connect local Codex chats

Install the supplied Codex lifecycle hooks:

```sh
python3 CodexIntegration/install.py
```

Then open a **new local Codex chat**, enter `/hooks`, and review and trust the four PhoneFocus hooks. [Codex requires this review](https://learn.chatgpt.com/docs/hooks) before new hooks can run. Keep PhoneFocus running with **Follow local Codex chats** enabled. Its main button pauses or resumes automatic monitoring. Turn that switch off to use manual monitoring.

The hooks mark a turn active at `UserPromptSubmit` and clear it at `Stop`, `Interrupt`, or `SessionEnd`. They create empty activity flags in `/private/tmp/phonefocus-codex-<user-id>`. Prompt text, response text, and transcripts are never written to these flags. PhoneFocus checks them twice per second and ignores flags older than one hour if a hook fails to clean up after a crash.

To disconnect, run:

```sh
python3 CodexIntegration/install.py --remove
```

The installer preserves any other Codex hooks and backs up an existing `~/.codex/hooks.json` before changing it. The integration covers **local Codex chats**. It does not detect ordinary ChatGPT chats or cloud-hosted turns.

## Camera angle

The app can select a camera, but macOS does not provide a usable field-of-view value for comparing cameras. An iPhone Continuity Camera is preferred by default; this is a preference, not a guarantee that it has the widest lens. To use an iPhone's Ultra Wide lens, select it in macOS **Video Effects → Center Stage** as [Apple describes](https://support.apple.com/en-us/111102). A Mac's built-in camera has a fixed physical viewing angle.

## Limits and privacy

PhoneFocus infers phone use from a visible phone near the primary person or a hand. It cannot prove that you are actively using the phone. Lighting, camera position, small phones, and occlusion affect accuracy. The five-second timer tolerates brief missed detections.

The app does not use the network at runtime. The build script downloads the Core ML model once. The app's only persistent preferences are the chosen audio path, camera choice, and automatic mode setting. Camera frames remain in memory during local processing.

## Repository files

```text
Sources/PhoneFocus.swift                 macOS app and detection logic
CodexIntegration/phonefocus_activity.py  local turn activity hook
CodexIntegration/install.py              hook installer and remover
Info.plist                               app metadata and camera permission text
FallbackChime.aiff                       backup alert sound
build.sh                                 model download and app build
```

The repository intentionally contains no downloaded model, compiled app, chat data, or Codex credentials.

