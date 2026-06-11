# Setup Completo SpotyPopup

## Passo 1: Crea Spotify App

1. Vai su https://developer.spotify.com/dashboard
2. Fai login con il tuo account Spotify
3. Clicca **"Create app"**
4. Compila:
   - **App name**: `SpotyPopup`
   - **App description**: `Menu bar controller for spotifyd`
   - **Redirect URI**: `spotypopup://callback` ⚠️ IMPORTANTE (custom URL scheme, non http)
   - **Which API/SDKs are you planning to use?**: Web API
5. Accetta i termini e clicca **"Save"**
6. Nella pagina dell'app, clicca **"Settings"**
7. Copia il **Client ID** (il Client Secret non serve più grazie a PKCE!)

## Passo 2: Configura il Client ID

Apri `Sources/SpotyPopup/SpotifyAuth.swift` e modifica:

**Riga 8:**
```swift
private let clientID = "metti_qui_il_client_id"
```

**Nota**: Non serve più il client secret! L'app usa PKCE (Proof Key for Code Exchange), che è lo standard sicuro per app native pubbliche.

## Passo 3: Verifica spotifyd

Assicurati che spotifyd sia in esecuzione:

```bash
# Verifica se è attivo
ps aux | grep spotifyd

# Se non è attivo, avvialo
spotifyd --no-daemon --backend portaudio
```

## Passo 4: Build e avvio

**Per far funzionare l'autenticazione devi creare l'app bundle:**

```bash
./build_app.sh
open SpotyPopup.app
```

Lo script crea `SpotyPopup.app` con l'Info.plist che registra il custom URL scheme `spotypopup://`.

**Per debug veloce (senza autenticazione funzionante):**
```bash
swift run
```

## Primo utilizzo

1. Apparirà un'icona musicale nella menu bar (in alto a destra)
2. Cliccala
3. Clicca **"Login with Spotify"**
4. Si aprirà il browser → autorizza l'app
5. Torna all'app (dovrebbe autenticarsi automaticamente)
6. Avvia musica su Spotify (da qualsiasi client)
7. L'app mostrerà la copertina e i controlli

## Troubleshooting

**"No active playback"**: 
- Verifica che spotifyd sia in esecuzione
- Avvia la riproduzione da Spotify web/mobile/desktop
- Seleziona spotifyd come dispositivo di output

**"Not authenticated" dopo il login**:
- Controlla che il redirect URI sia esattamente `spotypopup://callback`
- Verifica Client ID e Secret in `SpotifyAuth.swift`
- Se usi Xcode, assicurati che l'Info.plist sia incluso nel bundle

**Errori di build**:
- Richiede macOS 13+ e Swift 5.9+
- Prova `swift --version` per verificare
