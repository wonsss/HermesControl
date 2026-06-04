# HermesControl

A macOS menu bar companion for [Hermes Agent](https://hermes-agent.nousresearch.com) — toggle the
messaging gateway on/off, watch incoming requests in real time, follow the model's reasoning, and
switch models, all from the menu bar.

![build](https://github.com/wonsss/HermesControl/actions/workflows/build.yml/badge.svg)

![HermesControl](docs/screenshot.png)

## Why

When Hermes' gateway is running, your Mac answers Telegram/Discord/Slack messages whenever it's
awake. HermesControl gives you an explicit switch for that, plus visibility into what the agent is
doing right now:

- **Gateway toggle** — turn the gateway ON/OFF from the menu bar. OFF stays off across logins
  (it patches the launch agent's `RunAtLoad`), so an awake Mac is no longer always-connected.
- **Live activity** — see the current inbound request (platform, sender, message, elapsed time) and
  a list of recent ones.
- **Thinking window** — click a request to open per-turn reasoning, plus a Conversation tab showing
  the user/assistant messages. Both update live while a request is processing.
- **Token & cost** — per-session input / output / reasoning tokens and estimated cost.
- **Model switcher** — switch between the models defined in your Hermes config; the gateway restarts
  automatically.
- **Notifications** — get a macOS notification when a request arrives; click it to open the Thinking
  window.

## Requirements

- macOS 14 (Sonoma) or later.
- [Hermes Agent](https://hermes-agent.nousresearch.com) installed (`~/.hermes`). HermesControl reads
  Hermes' state DB and config and drives the `hermes` CLI — it does nothing useful without it.
  A non-default Hermes home is honored via the `HERMES_HOME` environment variable.

## Install

### Download (recommended)

Grab the notarized `HermesControl-notarized.zip` from
[Releases](https://github.com/wonsss/HermesControl/releases), unzip, and move `HermesControl.app`
to `/Applications`. On first launch the app offers to install itself there.

### Build from source

```bash
git clone https://github.com/wonsss/HermesControl.git
cd HermesControl
./build.sh                       # builds HermesControl.app (signs if a Developer ID cert exists)
open HermesControl.app
```

Requires the Swift toolchain (Xcode or Command Line Tools).

### Gatekeeper

If you build/sign locally without notarization, macOS may block first launch. Either right-click the
app → **Open**, or clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine HermesControl.app
```

## Usage

The app lives in the menu bar (no Dock icon). The label shows `ON`/`OFF`, or a spinner + platform
code while a request is being processed.

- Click the icon for the status popover: gateway toggle, recent activity, model switcher.
- Click a request row to open the **Thinking** window (reasoning + conversation, live).
- The 🔔 button requests notification permission / sends a test.

## Development

```bash
swift build       # debug build
swift test        # run the unit tests
swift format -i -r Sources/
```

## Notarization (maintainers)

```bash
./notarize.sh --store-credentials   # one-time: Apple ID + app-specific password
./notarize.sh                       # build, submit, staple → HermesControl-notarized.zip
```

## License

[MIT](LICENSE)
