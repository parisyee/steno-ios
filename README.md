# steno-ios

iOS app for Steno. Receives voice notes via the iOS share sheet, sends them to the Steno API for transcription, and displays the results.

## Related repos
- **`parisyee/steno`** — backend API (Cloud Run + Supabase)

## Architecture

```
Voice Memos app
      │
      │  (iOS Share Sheet)
      ▼
StenoShareExtension         ← receives the .m4a file
      │
      │  copies file to App Group shared container
      │  opens main app via steno:// URL scheme
      ▼
Steno (main app)            ← picks up file, calls API, shows result
      │
      │  POST /transcribe (multipart, Bearer auth)
      ▼
Steno API (Cloud Run)
https://steno-836899141951.us-central1.run.app
```

## Project structure

```
steno-ios/
├── Steno/
│   ├── StenoApp.swift          ← app entry point, handles steno:// URL scheme
│   └── ContentView.swift       ← transcription list UI with copy and delete
├── Shared/
│   ├── Config.swift            ← API URL, API key, App Group ID (edit before building)
│   ├── Transcription.swift     ← data model
│   └── TranscriptionStore.swift ← API calls, persistence via UserDefaults (App Group)
└── StenoShareExtension/
    ├── ShareViewController.swift ← handles incoming audio from share sheet
    └── Info.plist               ← activates only for audio files (public.audio UTI)
```

## Before you build

Edit `Shared/Config.swift`:

```swift
static let apiBaseURL  = "https://steno-836899141951.us-central1.run.app"
static let apiKey      = "YOUR_STENO_API_KEY"       // must match STENO_API_KEY on Cloud Run
static let appGroupID  = "group.com.yourname.steno" // must match App Group in Xcode
```

## Xcode setup (first time)

This repo contains source files only — the `.xcodeproj` is not committed. Create it once in Xcode:

1. **File → New → Project** → iOS App
   - Product Name: `Steno`
   - Organization Identifier: `com.yourname`
   - Interface: SwiftUI, Language: Swift
   - Save inside this folder

2. **Replace** the generated `StenoApp.swift` and `ContentView.swift` with the versions in `Steno/`

3. **Drag `Shared/`** into the project navigator → add to **both** targets when prompted

4. **File → New → Target** → Share Extension
   - Product Name: `StenoShareExtension`
   - Replace generated `ShareViewController.swift` and `Info.plist` with versions in `StenoShareExtension/`

5. **App Groups** — add to both targets (Signing & Capabilities → + Capability → App Groups):
   - `group.com.yourname.steno`

6. **URL Scheme** — add to the Steno target (Info → URL Types → +):
   - Scheme: `steno`, Identifier: `com.yourname.steno`

## Deploy to your phone

```
1. Plug in iPhone via USB
2. Select your phone as run destination in Xcode toolbar
3. Select the Steno scheme
4. Cmd+R to build and run
5. On phone: Settings → General → VPN & Device Management → trust your profile
```

Free Apple developer account: app re-signs every 7 days (just hit Cmd+R again).
Paid account ($99/yr): no re-signing needed.

## How the share flow works

1. User taps share on a voice memo in Voice Memos
2. `StenoShareExtension` appears in the share sheet (audio files only)
3. Extension copies the `.m4a` to the App Group shared container at `Config.sharedFileURL`
4. Extension opens `steno://transcribe` — iOS brings the main app to the foreground
5. Main app's `onOpenURL` fires → `TranscriptionStore.processSharedFile()` runs
6. File is read, deleted from shared container, POSTed to `/transcribe` as multipart
7. Response `{text, id}` is displayed and persisted locally in UserDefaults

## API contract

**Request:** `POST /transcribe`
```
Authorization: Bearer <STENO_API_KEY>
Content-Type: multipart/form-data
file: <audio.m4a>
```

**Response:**
```json
{ "text": "...", "id": "uuid" }
```

Timeout is set to 600s — long recordings can take several minutes to trim and transcribe.
