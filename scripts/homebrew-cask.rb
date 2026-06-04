# Homebrew Cask template for HermesControl.
# Before submitting: update version + sha256 after each release.
# sha256: shasum -a 256 HermesControl-<version>.dmg
#
# Self-tap (immediate):
#   gh repo create wonsss/homebrew-hermescontrol --public
#   Copy this file to Casks/hermescontrol.rb, update, push
#   Users: brew tap wonsss/hermescontrol && brew install --cask hermescontrol
cask "hermescontrol" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_OF_DMG"

  url "https://github.com/wonsss/HermesControl/releases/download/v#{version}/HermesControl-#{version}.dmg"
  name "Hermes Control"
  desc "macOS menu bar companion for Hermes Agent — gateway toggle, live activity, model switcher"
  homepage "https://github.com/wonsss/HermesControl"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "HermesControl.app"

  zap trash: [
    "~/Library/Application Support/io.github.wonsss.hermescontrol",
    "~/Library/Preferences/io.github.wonsss.hermescontrol.plist",
  ]
end
