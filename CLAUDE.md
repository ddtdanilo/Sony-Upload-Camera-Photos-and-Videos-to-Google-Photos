# CLAUDE.md - Project Intelligence

## Project Overview
Native macOS application (SwiftUI) for uploading photos and videos from a Sony A7III camera to Google Photos.

## Architecture
- **Pattern**: MVVM with Services layer
- **UI Framework**: SwiftUI
- **Target**: macOS 13.0+ (Universal Binary: Intel + Apple Silicon)
- **Dependencies**: None (uses native Keychain API, CommonCrypto for PKCE, loopback HTTP server for OAuth)

## Build & Run
```bash
# Build from command line
xcodebuild -project SonyCameraToGooglePhotos/SonyCameraToGooglePhotos.xcodeproj \
  -scheme SonyCameraToGooglePhotos \
  -destination 'platform=macOS' \
  build

# Or open in Xcode
open SonyCameraToGooglePhotos/SonyCameraToGooglePhotos.xcodeproj
```

## Key Conventions
- All Swift files use Swift 5.9+
- ViewModels are `@MainActor` classes conforming to `ObservableObject`
- Services are standalone classes, injected into ViewModels
- No force unwraps in production code
- Errors are surfaced to the user via alerts, never silently swallowed

## Google Photos API
- OAuth 2.0 with PKCE via loopback HTTP server redirect (no third-party auth library)
- Upload is a 2-step process: upload bytes → batchCreate media items
- Resumable uploads for files > 5MB
- Scopes: `https://www.googleapis.com/auth/photoslibrary.appendonly`

## Sony A7III SD Card Layout
- Photos: `DCIM/###MSDCF/*.{JPG,ARW}`
- Videos: `PRIVATE/M4ROOT/CLIP/*.MP4`

## Git Commits
- NEVER add Co-Authored-By lines for Claude or any AI assistant in commit messages

## Secrets / Credential Management

- OAuth credentials are loaded at runtime from Info.plist via `Bundle.main.infoDictionary`
- `Base.xcconfig` (committed) uses `#include?` to optionally include `Secrets.xcconfig` (gitignored)
- `Info.plist` uses `$(GOOGLE_CLIENT_ID)` / `$(GOOGLE_CLIENT_SECRET)` variable substitution
- For local development: copy `Secrets.xcconfig.example` → `Secrets.xcconfig` and fill in credentials
- For CI: GitHub Secrets inject values into a generated `Secrets.xcconfig` at build time
- NEVER commit actual credentials

## CI/CD

- `.github/workflows/build.yml` — builds on push to main / PRs
- `.github/workflows/release.yml` — archives + DMG + GitHub Release on tag push (v*.*.*)
- Both workflows generate `Secrets.xcconfig` from GitHub Secrets
