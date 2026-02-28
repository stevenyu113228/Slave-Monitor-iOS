# Slave Monitor

A native iOS terminal client for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) running on a remote Mac or Linux machine. Connect to multiple devices over Tailscale VPN, manage tmux sessions, and interact with Claude Code from your iPhone.

![Demo](img/img.jpg)

## Features

- **Native Terminal** — Full terminal emulator powered by [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm), with WebSocket connection to [ttyd](https://github.com/tsl0922/ttyd)
- **Multi-Device Profiles** — Save and switch between multiple remote machines, each with independent connections
- **Tmux Tab Management** — View, switch, create, rename, and close tmux windows directly from the app
- **Quick Keys** — Compact button bar for common terminal keys (`/`, `Tab`, `Esc`, `Enter`, `Ctrl+C`, `Ctrl+O`, `Ctrl+U`, arrow keys)
- **Dictation & Text Input** — Type or dictate commands with iOS native input, auto-submit on Enter
- **Photo Upload** — Send images to the remote machine for Claude Code to analyze
- **Auto-Reconnect** — Exponential backoff reconnection with background/foreground lifecycle handling
- **Quick Commands** — Preset command shortcuts for frequent operations

## Server Setup

This app requires the companion server running on your remote machine:

**[Claude-Code-Remote](https://github.com/stevenyu113228/Claude-Code-Remote)** — Sets up ttyd (terminal server on port 7681) and a FastAPI backend (on port 8080) inside a tmux session, all bound to your Tailscale IP.

Follow the server repo's setup instructions first, then connect from this app using your Tailscale IP.

## Install (Pre-built IPA)

If you don't have an Apple Developer account, you can sideload the pre-built IPA using [AltStore](https://altstore.io/):

1. Install **AltServer** on your Mac/PC ([download](https://altstore.io/))
2. Connect your iPhone via USB and install **AltStore** to your phone through AltServer
3. Download the latest `SlaveMonitor.ipa` from [Releases](https://github.com/stevenyu113228/Slave-Monitor-iOS/releases)
4. Open the downloaded IPA file and choose **Open with AltStore**
   - Or: open **AltStore** on your phone → **My Apps** → **+** → select the IPA
5. AltStore will sign and install the app automatically

AltServer running in the background will auto-refresh the signing every 7 days.

## Build from Source

### Requirements

- iOS 17.0+
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- [Tailscale](https://tailscale.com/) installed on both your iPhone and remote machine

### 1. Clone the repo

```bash
git clone https://github.com/stevenyu113228/Slave-Monitor-iOS.git
cd Slave-Monitor-iOS
```

### 2. Generate Xcode project

```bash
brew install xcodegen   # if not installed
xcodegen generate
```

This generates `SlaveMonitor.xcodeproj` from `project.yml`.

### 3. Open in Xcode

```bash
open SlaveMonitor.xcodeproj
```

### 4. Configure signing

- Select the **SlaveMonitor** target
- Go to **Signing & Capabilities**
- Select your **Team** (Apple Developer account or free Apple ID)
- Update the **Bundle Identifier** to something unique (e.g. `com.yourname.slavemonitor`)

### 5. Build and run

- Connect your iPhone or select a simulator
- Press **Cmd+R** to build and run

### Command-line build (optional)

```bash
# Find your Team ID
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject

# Build for a connected device
xcodebuild -project SlaveMonitor.xcodeproj \
  -scheme SlaveMonitor \
  -destination 'generic/platform=iOS' \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  -allowProvisioningUpdates \
  build
```

## Usage

1. Make sure the [server](https://github.com/stevenyu113228/Claude-Code-Remote) is running on your remote machine
2. Open the app and tap **+** to add a device
3. Enter a name, your machine's Tailscale IP, and ports (defaults: ttyd 7681, API 8080)
4. Tap **Save** — the app connects automatically
5. Use the **device tab bar** to switch between machines
6. Use the **tmux tab bar** to manage terminal windows

## Architecture

```
iPhone App                          Remote Machine (Mac/Linux)
┌──────────────────┐               ┌──────────────────────────┐
│  DeviceTabBar    │               │  tmux session            │
│  ┌────────────┐  │  Tailscale   │  ├── Claude Code window  │
│  │TerminalView│◄─┼──WebSocket──►│  │   (ttyd :7681)        │
│  │ (SwiftTerm)│  │   :7681      │  └── ...                 │
│  └────────────┘  │               │                          │
│  TmuxTabBar      │               │  FastAPI backend         │
│  QuickKeys       │◄──REST API──►│  (:8080)                 │
│  InputBar        │   :8080       │  ├── /tmux/*             │
│  (dictation/photo│               │  └── /upload             │
└──────────────────┘               └──────────────────────────┘
```

## License

MIT
