# Hermes Control

**English** | [한국어](README.ko.md)

A native macOS menu bar app for [Hermes Agent](https://hermes-agent.nousresearch.com) that lets you control the Hermes messaging gateway, inspect live requests, follow the model's reasoning, and switch models without touching the terminal.

[![build](https://github.com/wonsss/HermesControl/actions/workflows/build.yml/badge.svg)](https://github.com/wonsss/HermesControl/actions/workflows/build.yml)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Hermes Agent](https://img.shields.io/badge/Hermes-Agent-required-orange)
![Swift 6](https://img.shields.io/badge/Swift-6-red)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [How It Works](#how-it-works)
- [Notarization](#notarization)
- [Security](#security)
- [License](#license)

## Features

- **Gateway control** — Turn the Hermes messaging gateway on or off from the menu bar
- **Persistent disconnect** — OFF stays OFF across logins by patching Hermes' launch agent `RunAtLoad`
- **Live request tracking** — See the current inbound request with platform, sender, message, and elapsed time
- **Thinking window** — Open a live reasoning view plus the user/assistant conversation for the active request
- **Recent activity** — Review the latest completed or cancelled sessions directly from the popover
- **Force cancel** — Interrupt the current Hermes session from the popover or the live Thinking window
- **Token and cost view** — Inspect input, output, reasoning tokens, and estimated session cost
- **Model switching** — Switch between models defined in Hermes config; the gateway restarts automatically
- **Notifications** — Get a macOS notification when a new request arrives
- **Move to /Applications** — Prompts on first launch if the app is running from another folder

## Requirements

| Requirement | Detail |
|---|---|
| macOS | 14.0 (Sonoma) or later |
| Hermes Agent | Installed and configured locally |
| Hermes home | Default `~/.hermes`, or custom location via `HERMES_HOME` |
| Hermes CLI | `hermes` must be available from PATH or Hermes' standard install location |

Hermes Control reads Hermes' local state database and config, and controls the Hermes gateway process. Without Hermes Agent installed, the app has nothing to manage.

## Installation

### Option A — Download the notarized app (recommended)

1. Open [Releases](https://github.com/wonsss/HermesControl/releases)
2. Download the latest `HermesControl-x.y.z.dmg`
3. Open the DMG and drag `HermesControl.app` to `/Applications`
4. Launch `HermesControl.app`

You can also download `HermesControl-notarized.zip` from the same release page if you prefer a ZIP artifact.

### Option B — Build from source

```bash
git clone https://github.com/wonsss/HermesControl.git
cd HermesControl
./build.sh
open HermesControl.app
```

If you want the built app in `/Applications`, launch it once and accept the move/install prompt.

Requires Xcode Command Line Tools:

```bash
xcode-select --install
```

### Gatekeeper

The GitHub Release DMG is notarized and should open normally.

If you build locally and macOS blocks first launch, either right-click the app and choose **Open**, or clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine HermesControl.app
```

## Usage

1. Install and configure [Hermes Agent](https://hermes-agent.nousresearch.com)
2. Launch `HermesControl.app`
3. Click the menu bar item to open the status popover
4. Use **Connect** / **Disconnect** to control the Hermes gateway
5. Click an active or recent request to open the Thinking window
6. Use the force-cancel button if you need to stop the active session
7. Change models from the built-in model list when needed

## How It Works

- Hermes Control monitors Hermes' local gateway log and state database
- It reads model options from Hermes config and displays the currently active model
- It queries session metadata from Hermes' SQLite state database to show reasoning, conversation, token usage, and cost
- It restarts the Hermes gateway when model changes or forced cancellation require it

## Notarization

For maintainers with an Apple Developer Program membership and a valid `Developer ID Application` certificate:

```bash
./notarize.sh --store-credentials
./notarize.sh
```

This builds the app, signs it, submits it to Apple notarization, staples the ticket, and produces `HermesControl-notarized.zip` for GitHub Releases.

## Security

- **No shell string interpolation for untrusted input** — subprocesses use explicit argument arrays
- **Model/config validation** — model ID, provider, and base URL are validated before config writes
- **Tool discovery** — Hermes binaries are discovered via PATH and common install locations, not hardcoded user paths
- **Local-only control plane** — the app reads Hermes state locally and does not add its own external network service

## License

MIT — see [LICENSE](LICENSE)
