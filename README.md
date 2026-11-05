# spotlight-watchdog

A tiny daily check that tells you when macOS Spotlight has silently stopped indexing.

## The problem

Spotlight can stop indexing without any visible error. New apps never show up in search, new files can't be found, and everything that was already indexed still works, so it's easy not to notice for weeks.

One way this happens: after a long uptime, Spotlight's index process (`mds_stores`) restarts and loses its connection to the main daemon (`mds`). The system log fills with lines like:

```
mds_stores: si_remote_ctx_connection_send_message:81: oid_to_path error ... Connection interrupted
```

and no indexing workers (`mdworker_shared`) run.

## The fix

Restart your Mac. Or, without restarting:

```bash
sudo killall mds mds_stores
```

launchd brings both back. If some apps are still missing a few minutes later, rebuild the index (this takes a while):

```bash
sudo mdutil -E /
```

## What the watchdog does

Once a day it:

1. Writes a file with a unique token and checks Spotlight finds it within 60 seconds.
2. Checks every app in `/Applications` and `~/Applications` is in the index. Symlinked apps (which Spotlight never indexes) and apps installed in the last hour (which may still be indexing) are skipped.

If either check fails, you get a macOS notification. Every run is logged to `~/Library/Logs/spotlight-watchdog.log`.

## Install

```bash
git clone https://github.com/thekindofme/spotlight-watchdog.git
cd spotlight-watchdog
./install.sh
```

This copies the script to `~/.local/bin/spotlight-watchdog` and adds a LaunchAgent that runs it daily at 10:00 (or on wake, if the Mac was asleep). No sudo needed.

Then run a check once by hand. If macOS asks whether Script Editor can send notifications, allow it, otherwise the daily warning will be silent:

```bash
spotlight-watchdog
```

It exits 0 when healthy and 1 when broken. `--quiet` skips the notification.

## Uninstall

```bash
./install.sh --uninstall
```

## Configuration

Environment variables, mostly for testing:

| Variable | Default |
| --- | --- |
| `SPOTLIGHT_WATCHDOG_APP_DIRS` | `/Applications:$HOME/Applications` |
| `SPOTLIGHT_WATCHDOG_TIMEOUT` | `60` (seconds to wait for the probe file) |
| `SPOTLIGHT_WATCHDOG_INTERVAL` | `5` (seconds between probe checks) |
| `SPOTLIGHT_WATCHDOG_GRACE` | `60` (minutes to skip newly installed apps; `0` turns it off) |
| `SPOTLIGHT_WATCHDOG_PROBE_DIR` | `~/Library/Application Support/spotlight-watchdog` |
| `SPOTLIGHT_WATCHDOG_LOG` | `~/Library/Logs/spotlight-watchdog.log` |

If you turned Spotlight off on purpose (`mdutil -i off`), this tool will always report it as broken.

## Development

```bash
tests/run.sh
shellcheck spotlight-watchdog install.sh tests/run.sh
```

The tests fake `mdfind`, so they don't touch your real index.

## License

MIT
