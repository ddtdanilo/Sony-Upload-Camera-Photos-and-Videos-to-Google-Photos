# Sony Camera → Google Photos

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/ddtdanilo)

A native macOS application for uploading photos and videos from a Sony A7III camera (or SD card) directly to Google Photos.

## Features

- **Google Sign-In** — Authenticate with your Google account via OAuth 2.0
- **Auto-detect Camera/SD Card** — Automatically detects when a Sony camera or SD card is connected
- **Browse Media** — View thumbnails of JPEG, ARW (RAW), and MP4 files in a grid layout
- **Batch Upload** — Select files and upload them to Google Photos with progress tracking
- **Resumable Uploads** — Large video files use resumable uploads to handle interruptions
- **Universal Binary** — Runs natively on both Intel and Apple Silicon Macs

## Requirements

- macOS 13.0 (Ventura) or later
- A Google account with Google Photos
- A Google Cloud project with the Photos Library API enabled
- Sony A7III camera or compatible SD card

## Setup

### 1. Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or use an existing one)
3. Enable the **Photos Library API** ([direct link](https://console.cloud.google.com/apis/library/photoslibrary.googleapis.com))
4. Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID** ([direct link](https://console.cloud.google.com/apis/credentials))
5. Select **Desktop app** as the application type
6. Note the **Client ID** and **Client Secret**

### 2. Configure Credentials

Copy the example config and fill in your credentials:

```bash
cp SonyCameraToGooglePhotos/Secrets.xcconfig.example SonyCameraToGooglePhotos/Secrets.xcconfig
```

Edit `SonyCameraToGooglePhotos/Secrets.xcconfig`:

```
GOOGLE_CLIENT_ID = your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET = your-client-secret
```

> **Note:** `Secrets.xcconfig` is gitignored and will never be committed.

### 3. Build & Run

Open the Xcode project and build:

```bash
open SonyCameraToGooglePhotos/SonyCameraToGooglePhotos.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -project SonyCameraToGooglePhotos/SonyCameraToGooglePhotos.xcodeproj \
  -scheme SonyCameraToGooglePhotos \
  -destination 'platform=macOS' \
  build
```

If credentials are not configured, the app will show a setup guide with instructions instead of the login screen.

## CI/CD

GitHub Actions workflows are included:

- **Build** (`.github/workflows/build.yml`): Builds on every push to `main` and on PRs.
- **Release** (`.github/workflows/release.yml`): Creates a DMG and GitHub Release when you push a tag like `v1.0.0`.

Both workflows read `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` from GitHub Secrets and generate `Secrets.xcconfig` at build time.

### Creating a Release

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Usage

1. **Sign In** — Click "Sign in with Google" and authorize the app
2. **Connect Camera** — Plug in your Sony camera via USB or insert the SD card
3. **Browse** — The app detects the volume and shows your media files
4. **Select & Upload** — Choose files and click "Upload" to send them to Google Photos

## Architecture

```text
MVVM + Services
├── Models          — Data types (MediaItem, CameraVolume, etc.)
├── ViewModels      — Business logic, state management (@MainActor)
├── Views           — SwiftUI views
└── Services        — Google Auth, Photos API, Volume Detection, etc.
```

## Sony A7III SD Card Structure

The app scans these standard Sony folder paths:

| Content | Path Pattern | Extensions |
|---------|-------------|------------|
| Photos  | `DCIM/###MSDCF/` | `.JPG`, `.ARW` |
| Videos  | `PRIVATE/M4ROOT/CLIP/` | `.MP4` |

## License

MIT — see [LICENSE](LICENSE) for details.
