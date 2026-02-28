# Slave Monitor

> *Cyber Slave Surveillance System* — Monitor your AI slaves from the palm of your hand.

You've got Claude Code working for you on remote machines 24/7. But how do you keep an eye on your digital workforce while you're away from the desk? Easy — you pull out your phone and open Slave Monitor.

This is an iOS app that lets you watch, command, and manage Claude Code instances running on your Mac / Linux machines through [Tailscale](https://tailscale.com/) VPN. Think of it as a security camera for your AI sweatshop.

![Demo](img/img.jpg)

## What Can It Do

- **Real-time Terminal** — Watch your slaves type in real-time. Full terminal emulator powered by [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm), connected via WebSocket to [ttyd](https://github.com/tsl0922/ttyd)
- **Multi-Slave Management** — Register multiple machines, switch between them with one tap. Each slave maintains its own independent connection
- **Tmux Window Control** — Assign multiple tasks to the same machine. View, switch, create, rename, and close tmux windows without touching a keyboard
- **Quick Keys** — A compact control panel for when you need to intervene: `Ctrl+C` to stop a runaway slave, `Enter` to approve, arrow keys to navigate
- **Voice Commands** — Too lazy to type? Dictate your orders. iOS speech-to-text does the rest
- **Photo Upload** — Send screenshots or images to the remote machine for Claude to analyze. Because sometimes you need to show, not tell
- **Auto-Reconnect** — Slaves don't get to disconnect. If the connection drops, exponential backoff keeps retrying until it's back
- **Quick Commands** — One-tap preset commands for frequent orders

## Prerequisites

Your slaves need to be set up first. Install the server-side components on each remote machine:

**[Slave-Monitor-Server](https://github.com/stevenyu113228/Slave-Monitor-Server)** — Deploys ttyd (terminal server on port 7681) and a FastAPI backend (on port 8080) inside a tmux session, all bound to your Tailscale IP.

Set up the server, then connect from this app. Your slaves are ready to be monitored.

## Install (Sideload IPA)

No Apple Developer tax needed. Sideload using [AltStore](https://altstore.io/):

1. Install **AltServer** on your Mac/PC ([download](https://altstore.io/))
2. Connect your iPhone via USB → install **AltStore** to your phone
3. Download `SlaveMonitor.ipa` from [Releases](https://github.com/stevenyu113228/Slave-Monitor-iOS/releases)
4. Open the IPA → choose **Open with AltStore**
   - Or: **AltStore** → **My Apps** → **+** → select the IPA
5. Done. AltStore auto-refreshes the signing every 7 days

## Build from Source

For those who trust no one (respect).

### Requirements

- iOS 17.0+
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- [Tailscale](https://tailscale.com/) on both your iPhone and the slave machines

### Steps

```bash
git clone https://github.com/stevenyu113228/Slave-Monitor-iOS.git
cd Slave-Monitor-iOS
brew install xcodegen    # if needed
xcodegen generate
open SlaveMonitor.xcodeproj
```

In Xcode:
1. Select **SlaveMonitor** target → **Signing & Capabilities**
2. Pick your Team (free Apple ID works)
3. Change Bundle Identifier to something unique (e.g. `com.yourname.slavemonitor`)
4. **Cmd+R** → build and deploy

<details>
<summary>Command-line build (headless)</summary>

```bash
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject

xcodebuild -project SlaveMonitor.xcodeproj \
  -scheme SlaveMonitor \
  -destination 'generic/platform=iOS' \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  -allowProvisioningUpdates \
  build
```
</details>

## Usage

1. Start the [server](https://github.com/stevenyu113228/Slave-Monitor-Server) on your remote machine(s)
2. Open the app → tap **+** → register a slave (name, Tailscale IP, ports)
3. Tap **Save** → connection established, surveillance begins
4. **Device tab bar** — switch between slaves
5. **Tmux tab bar** — switch between tasks on the same slave
6. Sit back and watch them work

## Architecture

```
  Your Phone                         Slave Machine (Mac/Linux)
┌──────────────────┐               ┌──────────────────────────┐
│  Device Tabs     │               │  tmux session            │
│  ┌────────────┐  │  Tailscale   │  ├── Claude Code (slave) │
│  │  Terminal  │◄─┼──WebSocket──►│  │   (ttyd :7681)        │
│  │ (SwiftTerm)│  │   :7681      │  └── ...                 │
│  └────────────┘  │               │                          │
│  Tmux Tabs       │               │  FastAPI backend         │
│  Quick Keys      │◄──REST API──►│  (:8080)                 │
│  Input Bar       │   :8080       │  ├── /tmux/*             │
│  (voice/photo)   │               │  └── /upload             │
└──────────────────┘               └──────────────────────────┘
        Boss                              Slave(s)
```

## License

MIT — Use it however you want. Your slaves have no say in this.
