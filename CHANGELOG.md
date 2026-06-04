# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/), versioning: [SemVer](https://semver.org/).

## [Unreleased]

## [1.0.1] - 2026-06-04
### Added
- Force cancel button for the active Hermes session in the processing row and live Thinking window.

### Changed
- Cancelled sessions are now recorded in recent activity with a red cancelled state.

## [1.0.0] - 2026-06-04
### Added
- Menu bar toggle for the Hermes gateway (ON/OFF) with live status.
- Activity feed: shows the current inbound request (platform, user, message, elapsed) and recent history.
- Thinking window: per-turn reasoning and a Conversation tab, updated live while a request is processing.
- Per-session token usage (input / output / reasoning) and estimated cost.
- Model switcher reading available models from Hermes config; local (MLX) and cloud models grouped separately.
- macOS notifications when a request arrives; click to open the Thinking window.
- Color-coded menu bar icon: green dot (connected + model ready), yellow (connected, no model loaded), grey (off), blinking orange (request in progress).
- Model availability badges: local models show ready/unavailable based on the actual `--model` arg of the running mlx_lm.server process; cloud models reflect gateway state.
- Connect / Disconnect labels with explicit gateway plist patching so OFF persists across reboots.

[Unreleased]: https://github.com/wonsss/HermesControl/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/wonsss/HermesControl/releases/tag/v1.0.1
[1.0.0]: https://github.com/wonsss/HermesControl/releases/tag/v1.0.0
