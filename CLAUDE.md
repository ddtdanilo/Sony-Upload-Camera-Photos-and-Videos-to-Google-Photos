# CLAUDE.md - Project Intelligence

## Project Overview
Native macOS application (SwiftUI) for uploading photos and videos from a Sony A7III camera to Google Photos.

## Architecture
- **Pattern**: MVVM with Services layer
- **UI Framework**: SwiftUI
- **Target**: macOS 13.0+ (Universal Binary: Intel + Apple Silicon)
- **Dependencies**: AppAuth (OAuth 2.0), KeychainAccess (Keychain storage) via SPM

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
- OAuth 2.0 via AppAuth with loopback redirect (no custom URL scheme needed for auth)
- Upload is a 2-step process: upload bytes → batchCreate media items
- Resumable uploads for files > 5MB
- Scopes: `https://www.googleapis.com/auth/photoslibrary.appendonly`

## Sony A7III SD Card Layout
- Photos: `DCIM/###MSDCF/*.{JPG,ARW}`
- Videos: `PRIVATE/M4ROOT/CLIP/*.MP4`

## Secrets
- OAuth Client ID and Secret must be configured in Constants.swift
- NEVER commit actual credentials - the file contains placeholder values
