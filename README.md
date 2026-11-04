# Focus

A native macOS focus timer built with Swift and SwiftUI. Choose a 25, 45, or 60-minute preset or adjust focus duration from 1 to 240 minutes, take a five-minute break, manage a local task list, and track your daily goal. Changing duration resets the current paused timer. Focus keeps running in the menu bar when its window is closed.

## Requirements

- macOS 13 or later
- Xcode or the Xcode command line tools (to build)

## Build

```sh
./build.sh
```

The script creates a universal Intel and Apple Silicon app at `build/Focus.app` and a distributable archive at `build/Focus-macOS.zip`. It uses an ad-hoc signature, so macOS may require you to explicitly open the app through Finder the first time. The app is not notarized.

Focus stores its session history and preferences locally using UserDefaults. Focus shows an on-screen alert and plays a sound when a session ends, and reminds you to stand up and move every 20 minutes during a focus session. The timer continues during reminders; pause it if you want to take a longer break. Focus must remain running to show alerts; closing its window leaves it accessible in the menu bar, while **Quit Focus** stops it.
