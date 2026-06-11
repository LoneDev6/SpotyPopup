# SpotyPopup

Native macOS menu bar app for controlling spotifyd (Spotify headless daemon).\
It also works with Spotify client and Spotify PWA.

<img width="321" height="513" alt="SpotyPopup Screenshot" src="https://github.com/user-attachments/assets/f61f21e3-281c-4301-abea-f5dfe61013e1" />

## Features

- Playback controls (Play/Pause, Next, Previous)
- Album artwork display
- Native macOS menu bar integration
- Secure Spotify OAuth authentication via browser
- Lightweight and minimal UI

## Requirements

- macOS 13 or later
- Swift 5.9 or later
- spotifyd installed and running (or the Spotify client or the Spotify PWA)
- Spotify Premium account

## Setup

### 1. Create a Spotify App

Create an application on the Spotify Developer Dashboard:

1. Go to https://developer.spotify.com/dashboard
2. Click **Create App**
3. Enter any app name you prefer
4. Add the following Redirect URI:

```text
spotypopup://callback
````

5. Add the following scopes:

```text
user-read-playback-state
user-modify-playback-state
```

6. Save the application and copy the **Client ID**

> A Client Secret is not required.

### 2. Configure Your Client ID

Edit `Sources/SpotyPopup/SpotifyAuth.swift`:

```swift
private let clientID = "YOUR_CLIENT_ID"
```

### 3. Build and Run

#### Option A: App Bundle (Recommended)

```bash
./build_app.sh
open SpotyPopup.app
```

#### Option B: Direct Debug Run

```bash
swift run
```

> OAuth callbacks require the app bundle because the custom URL scheme (`spotypopup://callback`) must be registered with macOS.

## Usage

1. Launch SpotyPopup
2. Click the menu bar icon
3. Select **Login with Spotify**
4. Authorize the application in your browser
5. Start controlling Spotify playback directly from the menu bar

## Authentication

SpotyPopup uses **OAuth Authorization Code Flow with PKCE**.

Benefits:

* No client secret required
* Safe for public/open-source applications
* Recommended by Spotify for native apps
* Browser-based authentication

## Notes

* Playback information is retrieved using the Spotify Web API.
* Access and refresh tokens are stored locally to avoid repeated logins.
