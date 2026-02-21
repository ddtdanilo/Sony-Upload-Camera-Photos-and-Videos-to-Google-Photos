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

## Secrets
- OAuth Client ID and Secret must be configured in Constants.swift
- NEVER commit actual credentials - the file contains placeholder values
