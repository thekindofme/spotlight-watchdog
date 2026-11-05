# AGENTS.md

A tiny macOS tool: one bash script (`spotlight-watchdog`), an installer (`install.sh`) and tests (`tests/run.sh`).

## Rules

- Keep it minimal. No dependencies beyond stock macOS. Prefer deleting code to adding it.
- Scripts must run on the bash 3.2 that ships with macOS: no `mapfile`, associative arrays or `${var,,}`.
- Never require sudo to install or run. The fix commands in messages are for the user to run.
- Anything that talks to Spotlight goes through `$MDFIND` so tests can fake it.

## Before committing

```bash
tests/run.sh
shellcheck spotlight-watchdog install.sh tests/run.sh
```

Both must pass. Add a test for any behaviour change. Update README.md if usage or configuration changes.
