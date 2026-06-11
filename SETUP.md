# Complete SpotyPopup Setup

## Step 1: Create a Spotify App

1. Go to https://developer.spotify.com/dashboard
2. Sign in with your Spotify account
3. Click **"Create app"**
4. Fill in:
   - **App name**: `SpotyPopup`
   - **App description**: `Menu bar controller for spotifyd`
   - **Redirect URI**: `spotypopup://callback` ⚠️ IMPORTANT (custom URL scheme, not HTTP)
   - **Which API/SDKs are you planning to use?**: Web API
5. Accept the terms and click **"Save"**
6. On the app page, click **"Settings"**
7. Copy the **Client ID** (the Client Secret is no longer required thanks to PKCE!)

## Step 2: Configure the Client ID

Open `Sources/SpotyPopup/SpotifyAuth.swift` and edit:

**Line 8:**
```swift
private let clientID = "paste_your_client_id_here"
````

**Note**: A client secret is no longer required. The app uses PKCE (Proof Key for Code Exchange), which is the secure standard for public native applications.

## Step 3: Verify spotifyd

Make sure spotifyd is running:

```bash
# Check if it's running
ps aux | grep spotifyd

# If it's not running, start it
spotifyd --no-daemon --backend portaudio
```

## Step 4: Build and Launch

**To make authentication work, you must create the app bundle:**

```bash
./build_app.sh
open SpotyPopup.app
```

The script creates `SpotyPopup.app` with an Info.plist that registers the custom URL scheme `spotypopup://`.

**For quick debugging (authentication will not work):**

```bash
swift run
```

## First Use

1. A music icon will appear in the menu bar (top-right corner)
2. Click it
3. Click **"Login with Spotify"**
4. Your browser will open → authorize the app
5. Return to the app (it should authenticate automatically)
6. Start playing music on Spotify (from any client)
7. The app will display the album artwork and playback controls

## Troubleshooting

### "No active playback"

* Make sure spotifyd is running
* Start playback from Spotify Web, Mobile, or Desktop
* Select spotifyd as the playback device

### "Not authenticated" after login

* Ensure the redirect URI is exactly `spotypopup://callback`
* Verify the Client ID in `SpotifyAuth.swift`
* If you're using Xcode, make sure the Info.plist is included in the app bundle

### Build errors

* Requires macOS 13+ and Swift 5.9+
* Run `swift --version` to verify your Swift installation
