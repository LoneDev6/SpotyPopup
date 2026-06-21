# SpotyPopup - Project Specification

## Goal

SpotyPopup is a native macOS menu bar app for controlling Spotify playback, with special support for `spotifyd` as a local Spotify Connect device.

The app is designed to be a compact always-available controller: current playback, queue, devices, volume, and a temporary embedded Spotify Web Player for workflows that are not worth reimplementing natively.

## Current Feature Set

### Menu Bar App

- Runs as a macOS menu bar application.
- Opens a translucent AppKit popover from the status item.
- Uses a custom right-click menu on the menu bar icon for:
  - Settings
  - Quit
- Pauses Spotify playback when the app quits.

### Authentication

- Uses Spotify OAuth Authorization Code Flow with PKCE.
- Opens the system browser for login.
- Handles callback through:

```text
spotypopup://callback
```

- Allows the user to provide a Spotify Client ID in the login screen.
- Persists Spotify client ID, tokens, and token expiration in `UserDefaults`.
- Refreshes access tokens when possible.

### Playback Controls

- Shows current playback state:
  - Album artwork
  - Track title
  - Artist name
  - Progress bar
  - Playback state
- Supports:
  - Play / pause
  - Next
  - Previous
  - Volume control
  - Device selection
  - Queue view
- Stores the last selected volume and reapplies it on startup / device transfer.
- When playback state is lost, play attempts to recover by refreshing devices and targeting a usable Spotify Connect device.

### spotifyd Integration

- Detects whether `spotifyd` is installed.
- Supports install and uninstall from Settings.
- Shows only the currently valid action:
  - Install when missing
  - Uninstall when app-managed or Homebrew-managed
  - No destructive action for unknown system installs
- If installed through Homebrew, starts it through:

```bash
brew services start spotifyd
```

- If not using Homebrew, creates a user LaunchAgent for autorun.
- Can start `spotifyd` again when the Spotify Connect device disappears.
- Attempts to transfer playback to the local `spotifyd` device when appropriate.

### Queue

- Fetches and displays the Spotify queue.
- Opens queue view scrolled to the top.
- Shows the current track and next queued tracks.
- Displays a hover play affordance over album artwork in queue rows.
- Shows a blue volume indicator for the currently playing track.
- Supports a queue skip hack:
  - Clicking a queued track can skip forward to it.
  - Maximum skip distance is 10 tracks.
  - Skip is locked while another skip is already running.
  - Next / previous controls are disabled during skip.
  - macOS media next / previous commands are disabled during skip.
  - Temporarily mutes during skip and restores the original volume afterward, unless already muted.
  - Shows a blurred loading overlay while reaching the target track.

### Embedded Spotify Web Player

- Provides a large embedded WebKit view for `https://open.spotify.com`.
- Used for temporary full Spotify UI workflows such as selecting playlists and browsing Spotify content.
- Opens from the main playback UI.
- Album art opens Spotify Web Player.
- Artist name opens the artist page when an artist ID is available.
- Track name opens the album page when an album ID is available.
- Uses WebKit only; no Chromium or external browser dependency.
- Mutes page audio to avoid double playback while using `spotifyd`.
- Hides selected Spotify Web UI elements that are redundant or confusing in this app context.
- Saves the last visited Spotify Web URL and reopens it later.
- Saves a preview screenshot to disk and uses it as loading background to reduce white/black flash.
- Keeps a spinner while waiting for the web app to be ready.
- Provides a top bar with Back to avoid overlaying Spotify Web content.

### WebKit Memory Policy

Settings exposes a radio-button policy for WebKit lifecycle:

- `Instant`: destroy the WebView as soon as the user goes back.
- `After 30 seconds of no usage`: keep it briefly warm, then destroy it.
- `Never`: keep WebKit alive for fastest reopening.

The persisted WebKit data store remains on disk, but live page JavaScript and memory are only retained when the chosen policy keeps the WebView alive.

### Settings

Settings includes:

- spotifyd status and install/uninstall action.
- WebKit memory policy.
- Logout with confirmation popup.
- Project attribution:
  - Made by LoneDev
  - GitHub profile link
- Donation link:

```text
https://donate.devs.beer
```

## Technical Requirements

### Platform

- macOS 13 or newer.
- Swift 5.9.
- Swift Package Manager.
- AppKit-based UI.
- No third-party Swift package dependencies.

### Build

```bash
swift build
```

The repository also includes helper scripts for building the macOS app bundle.

## Architecture

```text
SpotyPopup/
├── Package.swift
├── SPECS.md
└── Sources/
    └── SpotyPopup/
        ├── main.swift
        ├── AppSettings.swift
        ├── Logger.swift
        ├── MenuBarController.swift
        ├── SpotifyAPI.swift
        ├── SpotifyAuth.swift
        ├── SpotifydManager.swift
        ├── StatusBarView.swift
        ├── Models/
        │   ├── PlaybackState.swift
        │   ├── Playlist.swift
        │   └── Track.swift
        └── Views/
            ├── MenuView.swift
            ├── QueueView.swift
            ├── ProgressBarView.swift
            ├── SettingsView.swift
            └── SpotifyWebPlayerView.swift
```

## Main Components

### `MenuBarController`

- Owns the `NSStatusItem`.
- Opens and closes the main popover.
- Opens Settings.
- Handles right-click menu actions.
- Integrates macOS media commands.
- Applies saved volume and local device transfer behavior.

### `MenuView`

- Main popover UI.
- Handles login screen, playback view, queue view, devices view, volume control, and embedded Spotify Web Player view.
- Requests preferred size changes when switching between compact player and large WebKit mode.

### `SpotifyAPI`

Spotify Web API client.

Core endpoints include:

- `GET /me/player`
- `PUT /me/player/play`
- `PUT /me/player/pause`
- `POST /me/player/next`
- `POST /me/player/previous`
- `GET /me/player/devices`
- `PUT /me/player`
- `PUT /me/player/volume`
- `GET /me/player/queue`
- playlist and library endpoints for playlist browsing.

### `SpotifyAuth`

- Handles OAuth PKCE.
- Builds Spotify auth URL.
- Exchanges authorization code for tokens.
- Refreshes tokens.
- Stores auth state locally.

### `SpotifydManager`

- Detects `spotifyd` install state.
- Installs managed `spotifyd` when needed.
- Supports Homebrew detection/start integration.
- Supports LaunchAgent creation for non-Homebrew autorun.
- Removes managed install and LaunchAgent on uninstall.

### `QueueView`

- Displays current and queued tracks.
- Handles queue-row hover UI.
- Triggers controlled queue skip behavior.
- Displays skip progress overlay.

### `SpotifyWebPlayerView`

- Wraps `WKWebView`.
- Handles loading, readiness detection, preview screenshot persistence, last URL persistence, and custom Spotify Web CSS/JS cleanup.
- Supports explicit close/recreate lifecycle for memory policy.

### `SettingsView`

- Provides spotifyd management, WebKit memory policy, account logout, project attribution, and donation links.

## Known Limitations

- Spotify does not expose a public API to reorder or remove arbitrary queue entries. Queue skip is implemented as a controlled multi-next workaround.
- Embedded Spotify Web Player layout and hidden elements depend on Spotify Web DOM behavior, which can change.
- Token storage currently uses `UserDefaults`, not Keychain.
- The app expects a valid Spotify Premium-capable playback environment for many player-control actions.
