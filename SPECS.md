# SpotyPopup - Project Specification

## Goal

A native macOS application that controls spotifyd (Spotify headless daemon) from the macOS menu bar.

## Functional Requirements

### Core Features

- **Menu Bar Icon**: App displayed as an icon in the macOS menu bar
- **Playback Controls**:
  - Play/Pause
  - Next Track
  - Previous Track
- **Now Playing Information**:
  - Current album artwork
  - Track title
  - Artist name
- **Minimal Interface**: Popup menu displayed when clicking the menu bar icon

### Future Features (Out of MVP Scope)

- Volume control
- Track progress bar
- Track change notifications

## Technical Requirements

### Technology Stack

**Swift + SwiftUI** (native macOS)

- Native menu bar application
- SwiftUI for the popup interface
- NSStatusBar for the menu bar icon
- Buildable using Swift Package Manager or Xcode

### Spotifyd Integration

- **Communication**: Spotify Web API (used to control playback on the spotifyd device)
  - spotifyd appears as a Spotify Connect device
  - Spotify Web API REST endpoints are used for playback control
- **Authentication**: Spotify OAuth user authentication
- **Dependencies**: spotifyd must already be installed, configured, and running

### Build Requirements

- Easy to compile without complex setup
- Preferably a single-command build process
- No unusual or difficult-to-install dependencies

## Architecture

```text
SpotyPopup/
├── Sources/
│   └── SpotyPopup/
│       ├── SpotyPopupApp.swift      # Entry point + AppDelegate
│       ├── MenuBarController.swift  # NSStatusBar management
│       ├── SpotifyAPI.swift         # Spotify Web API client
│       ├── Models/
│       │   ├── Track.swift
│       │   └── PlaybackState.swift
│       └── Views/
│           └── MenuView.swift       # Popup content (SwiftUI)
├── Resources/
│   └── Assets.xcassets/             # Menu bar icons
└── Package.swift                    # SPM manifest
````

## Swift Components

### MenuBarController

Responsible for managing the NSStatusItem and showing/hiding the popup menu.

### SpotifyAPI

HTTP client responsible for interacting with Spotify Web API endpoints:

* `GET /me/player` (current playback state)
* `PUT /me/player/play`
* `PUT /me/player/pause`
* `POST /me/player/next`
* `POST /me/player/previous`

### MenuView

SwiftUI view displaying:

* Album artwork
* Track title
* Artist name
* Playback controls

## Open Questions

1. ~~Technology stack~~: ✅ Swift + SwiftUI
2. ~~Scope~~: ✅ Basic playback controls and track information only, no search functionality
3. **Design**: Should dark mode support follow the system appearance automatically?
4. **Persistence**: Should Spotify OAuth tokens be stored in Keychain?
5. **Installation**: .app bundle required (bundle identifier needed)

## Recommended Decisions

### Dark Mode

Use the system appearance automatically. SwiftUI handles this natively and provides the most macOS-consistent experience.

### Token Storage

Store OAuth access and refresh tokens in the macOS Keychain. This is the standard and secure approach for native macOS applications.

### Authentication

Use Spotify OAuth Authorization Code Flow with PKCE.

Benefits:

* No client secret required
* Recommended by Spotify for native applications
* More secure than embedded secrets
* Works perfectly with a custom URL scheme such as:

```text
spotypopup://callback
```

## Next Steps

* [ ] Create Swift project structure and Package.swift
* [ ] Implement MenuBarController (menu bar icon and popup)
* [ ] Implement SpotifyAPI client
* [ ] Create MenuView SwiftUI layout
* [ ] Implement Spotify OAuth authentication with PKCE
* [ ] Store tokens securely in Keychain
* [ ] Add asynchronous album artwork loading
* [ ] Test with a running spotifyd instance
* [ ] Build distributable .app bundle
