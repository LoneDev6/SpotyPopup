# SpotyPopup - Specifiche Progetto

## Obiettivo
Applicazione nativa macOS per controllare spotifyd (Spotify headless daemon) tramite menu bar.

## Requisiti Funzionali

### Core Features
- **Menu Bar Icon**: App come icona nella barra superiore del Mac
- **Controlli Playback**: 
  - Play/Pausa
  - Traccia successiva
  - Traccia precedente
- **Visualizzazione**:
  - Copertina album corrente
  - Nome brano
  - Nome artista
- **Interfaccia Minimale**: Popup menu quando si clicca sull'icona

### Funzionalità Future (fuori scope MVP)
- Volume control
- Barra di progresso del brano
- Notifiche cambio brano

## Requisiti Tecnici

### Stack Tecnologico
**Swift + SwiftUI** (macOS nativo)
- App menu bar nativa
- SwiftUI per il popup menu
- NSStatusBar per l'icona nella barra
- Build con Swift Package Manager o Xcode

### Integrazione Spotifyd
- **Comunicazione**: Spotify Web API (per controllare il playback su spotifyd device)
  - Spotifyd appare come device Spotify Connect
  - Usiamo API REST di Spotify per controllarlo
- **Autenticazione**: Token OAuth Spotify (client credentials o user auth)
- **Dipendenze**: spotifyd deve essere già installato, configurato e in esecuzione

### Build Requirements
- Facile da compilare senza configurazioni complesse
- Possibilmente single command build
- No dipendenze esotiche

## Architettura

```
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
└── Package.swift                     # SPM manifest
```

### Componenti Swift
- **MenuBarController**: Gestisce NSStatusItem e mostra/nasconde popup
- **SpotifyAPI**: HTTP client per Spotify Web API endpoints
  - GET /me/player (current playback)
  - PUT /me/player/play
  - PUT /me/player/pause
  - POST /me/player/next
  - POST /me/player/previous
- **MenuView**: SwiftUI view con copertina + controlli

## Domande Aperte

1. ~~**Stack tecnologico**~~: ✅ Swift + SwiftUI
2. ~~**Scope**~~: ✅ Solo controlli base + info brano, no ricerca
3. **Design**: Dark mode support automatico (system default)?
4. **Persistenza**: Salvare token Spotify in Keychain?
5. **Installazione**: .app bundle (bundle identifier necessario)

## Next Steps
- [ ] Setup progetto Swift (Package.swift + struttura cartelle)
- [ ] Implementare MenuBarController (icona + status item)
- [ ] Implementare SpotifyAPI client (HTTP calls)
- [ ] Creare MenuView SwiftUI (layout base)
- [ ] Gestire autenticazione Spotify OAuth
- [ ] Integrare copertina album (async image loading)
- [ ] Testing con spotifyd in esecuzione
