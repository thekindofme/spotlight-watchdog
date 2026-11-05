#!/bin/bash
# Install spotlight-watchdog to ~/.local/bin and schedule it daily at 10:00.
# Usage: ./install.sh [--uninstall]
set -e

LABEL=com.github.thekindofme.spotlight-watchdog
BIN="$HOME/.local/bin/spotlight-watchdog"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user, not with sudo." >&2
  exit 1
fi

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true

if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$BIN" "$PLIST"
  rm -rf "$HOME/Library/Application Support/spotlight-watchdog"
  echo "Uninstalled."
  exit 0
fi

mkdir -p "$(dirname "$BIN")" "$(dirname "$PLIST")"
install -m 755 "$(dirname "$0")/spotlight-watchdog" "$BIN"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$BIN</string></array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/spotlight-watchdog.out.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/spotlight-watchdog.out.log</string>
</dict>
</plist>
EOF

launchctl bootstrap "$DOMAIN" "$PLIST"
echo "Installed. Runs daily at 10:00."
echo "Run spotlight-watchdog once now and allow notifications if macOS asks."
