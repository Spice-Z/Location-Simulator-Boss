# Location Simulator Boss

<img width="512" height="512" alt="Image" src="https://github.com/user-attachments/assets/ce8a2125-72c6-4bdc-a2ef-68d047435910" />

This is a macOS application that allows you to simulate a location on a map.

## Features

- Simulate a location on a map
- Edit routes
- Save routes to favorites
- Load routes from favorites
- Export/Import routes as JSON files
- Start simulation
- Stop simulation
- View simulation results

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building)

## Building

### Build from Xcode

1. Open `Location Simulator Boss.xcodeproj` in Xcode
2. Select **Product → Archive**
3. Click **Distribute App → Copy App**

### Build from Terminal

```bash
# Build Release version
xcodebuild -project "Location Simulator Boss.xcodeproj" \
  -scheme "Location Simulator Boss" \
  -configuration Release \
  -derivedDataPath build \
  clean build
```

The app will be at: `build/Build/Products/Release/Location Simulator Boss.app`

### Create DMG for Distribution

```bash
# Create DMG file
hdiutil create -volname "Location Simulator Boss" \
  -srcfolder "build/Build/Products/Release/Location Simulator Boss.app" \
  -ov -format UDZO \
  "Location_Simulator_Boss.dmg"
```

## Installation

1. Download `Location_Simulator_Boss.dmg` from [Releases](https://github.com/Spice-Z/Location-Simulator-Boss/releases)
2. Open the DMG and drag the app to Applications
3. First launch: Right-click → **Open** → **Open** (to bypass Gatekeeper since the app is not signed)

## Screenshots


