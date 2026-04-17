# Steno iOS — Setup Guide

## Step 1: Create the Xcode project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**, click Next
3. Product Name: `Steno`
4. Organization Identifier: `com.yourname` (use your actual domain or name)
5. Interface: **SwiftUI**, Language: **Swift**
6. Save it inside the `Steno/` folder (so `Steno.xcodeproj` lives next to the folders)

## Step 2: Add the source files

### Main app files
- Xcode created `StenoApp.swift` and `ContentView.swift` — **replace their contents** with the versions in `Steno/`

### Shared files
- Drag the `Shared/` folder into the Xcode project navigator
- When prompted, check **both** targets (Steno and the Share Extension you'll create next)
- This gives both targets access to `Config.swift`, `Transcription.swift`, and `TranscriptionStore.swift`

## Step 3: Add the Share Extension target

1. **File → New → Target**
2. Choose **iOS → Share Extension**, click Next
3. Product Name: `StenoShareExtension`
4. Click Finish (activate the scheme if prompted)
5. Replace the generated `ShareViewController.swift` with the version in `StenoShareExtension/`
6. Replace the generated `Info.plist` with the version in `StenoShareExtension/`

## Step 4: Configure App Groups

Both targets need to share data. Do this for **each** target (Steno and StenoShareExtension):

1. Select the target in Xcode
2. Go to **Signing & Capabilities**
3. Click **+ Capability → App Groups**
4. Add: `group.com.yourname.steno` (must match `Config.appGroupID`)

## Step 5: Add URL Scheme

This lets the Share Extension open the main app:

1. Select the **Steno** target
2. Go to **Info → URL Types**
3. Click **+**
4. URL Schemes: `steno`
5. Identifier: `com.yourname.steno`

## Step 6: Configure your backend

Edit `Shared/Config.swift`:

```swift
static let apiBaseURL = "https://your-actual-steno-url.com"
static let transcribePath = "/transcribe"     // adjust to match your API
static let apiKey = "your-actual-api-key"
static let appGroupID = "group.com.yourname.steno"  // must match Step 4
```

## Step 7: Deploy to your phone

1. Plug in your iPhone via USB
2. Select your phone as the run destination in Xcode's toolbar
3. Select the **Steno** scheme (not StenoShareExtension)
4. Click **Run** (or Cmd+R)
5. On first run, your phone may say "Untrusted Developer" — go to:
   **Settings → General → VPN & Device Management** → tap your profile → Trust
6. Run again from Xcode

## Testing

1. Open **Voice Memos** on your iPhone
2. Record a short note
3. Tap the voice memo → tap the **share icon** (box with arrow)
4. Scroll the app row and tap **Steno**
5. Tap **Post**
6. The Steno app opens and shows the transcription

## API Response Format

The app expects your Steno backend to return JSON:

```json
{
  "text": "The transcribed text goes here"
}
```

Adjust the parsing in `TranscriptionStore.swift` if your API returns a different format.
