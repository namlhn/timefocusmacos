# Focus

A native macOS focus timer built with Swift and SwiftUI. Choose a 25, 45, or 60-minute focus session, take a five-minute break, and track your daily goal. Focus keeps running in the menu bar when its window is closed.

## Requirements

- macOS 13 or later
- Xcode or the Xcode command line tools (to build)

## Build

```sh
./build.sh
```

The script creates a universal Intel and Apple Silicon app at `build/Focus.app` and a distributable archive at `build/Focus-macOS.zip`. It uses an ad-hoc signature, so macOS may require you to explicitly open the app through Finder the first time. The app is not notarized.

Focus stores its session history and preferences locally using UserDefaults. Allow notifications when prompted. Focus must remain running to alert you when a session ends; closing its window leaves it accessible in the menu bar, while **Quit Focus** stops it.
