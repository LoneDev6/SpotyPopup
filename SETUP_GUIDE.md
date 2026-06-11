# SpotyPopup Setup Guide

## How to Get Your Spotify Client ID

To use SpotyPopup, you need to create a Spotify application and obtain a Client ID. Follow these steps:

### Step 1: Go to Spotify Developer Dashboard

Navigate to: [https://developer.spotify.com/dashboard/](https://developer.spotify.com/dashboard/)

### Step 2: Log In

Log in with your Spotify account credentials.

### Step 3: Create an App

1. Click on the **"Create app"** button
2. Fill in the required information:
   - **App name**: Choose any name (e.g., "SpotyPopup")
   - **App description**: Add a brief description (e.g., "macOS menu bar Spotify controller")
   - **Redirect URI**: Enter `spotypopup://callback`
   - **API/SDKs**: Check **"Web Playback SDK"**

3. Accept the Terms of Service
4. Click **"Save"**

### Step 4: Enable Web Playback SDK

1. Once your app is created, click on it to view the settings
2. Go to the **"Settings"** section
3. Make sure **"Web Playback SDK"** is enabled

### Step 5: Get Your Client ID

1. In your app's dashboard, you'll see the **Client ID** field
2. Click the **"Show client secret"** button if needed
3. Copy your **Client ID** (a long string of letters and numbers)

### Step 6: Enter Client ID in SpotyPopup

1. Open SpotyPopup
2. Paste your Client ID into the input field
3. Click **"Login with Spotify"**

That's it! You're now ready to use SpotyPopup.

---

## Troubleshooting

### Authentication Fails

- Make sure you entered the correct Client ID (no extra spaces)
- Verify that the Redirect URI in your Spotify app settings is exactly: `spotypopup://callback`
- Ensure **Web Playback SDK** is enabled in your app settings

### Can't Find Client ID

- Go back to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard/)
- Click on your app
- The Client ID is displayed at the top of the page

### Need to Change Client ID

- Simply enter a new Client ID in the login screen
- The app will save and use the new one for authentication
