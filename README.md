# previewer

Small macOS Audio Unit host app built with SwiftUI/AppKit. It opens a persistent window, lists installed instrument Audio Units, loads the selected plugin, embeds its UI when available, and lets you play a quick preview note.

## Run

```bash
swift run previewer
```

## What it does

- Shows installed instrument Audio Units in a list
- Keeps the host window open until you close it
- Loads the selected Audio Unit into an `AVAudioEngine`
- Embeds the plugin UI if the Audio Unit exposes an embeddable view controller
- Plays a preview `C4` note with the `Play C4` button

## Notes

- The app currently lists `kAudioUnitType_MusicDevice` components, which covers instrument-style Audio Units.
- Some plugins do not provide an embeddable Cocoa UI. Those will still load, but the app will show a fallback message instead of a plugin editor.
