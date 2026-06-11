# SpotyPopup

Menu bar app nativa macOS per controllare spotifyd (Spotify headless daemon).

## Features

- 🎵 Controlli playback (play/pause/next/previous)
- 🖼️ Visualizzazione copertina album
- 📱 Menu bar nativo macOS
- 🔐 Autenticazione OAuth via browser

## Setup

### 1. Spotify Developer App

Crea una app su [Spotify Developer Dashboard](https://developer.spotify.com/dashboard):

1. Vai su https://developer.spotify.com/dashboard
2. Clicca "Create app"
3. Nome: `SpotyPopup` (o quello che vuoi)
4. Redirect URI: `spotypopup://callback`
5. Scopes necessari: `user-read-playback-state`, `user-modify-playback-state`
6. Salva solo il **Client ID** (secret non necessario)

### 2. Configura Client ID

Modifica `Sources/SpotyPopup/SpotifyAuth.swift`:

```swift
private let clientID = "TUO_CLIENT_ID_QUI"
```

**Sicurezza**: L'app usa PKCE, quindi NON serve il client secret. È sicura da pubblicare!

### 3. Build ed esegui

**Opzione A - App Bundle (raccomandato per uso normale):**

```bash
./build_app.sh
open SpotyPopup.app
```

**Opzione B - Debug diretto:**

```bash
swift run
```

Note: Per usare il custom URL scheme (`spotypopup://callback`) serve l'app bundle. Se usi `swift run` direttamente, il redirect OAuth non funzionerà.

## Requisiti

- macOS 13+
- spotifyd installato e in esecuzione
- Swift 5.9+

## Utilizzo

1. Clicca l'icona nella menu bar
2. Al primo avvio, clicca "Login with Spotify"
3. Autorizza l'app nel browser
4. Inizia a controllare la musica!

## Note

- spotifyd deve essere in esecuzione per funzionare
- L'app usa Spotify Web API per controllare il playback
- Autenticazione via **PKCE** (sicura per app pubbliche, no secret necessario)
- Il token viene salvato in UserDefaults
