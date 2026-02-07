# claude-usage

Claude usage in your menu bar. 81 lines of Swift.

```
◇ 34%
┌────────────────────┐
│ 5h 34% ↻ 4h02m     │
│ 7d 30% ↻ 70h02m    │
│ opus ·              │
│ sonnet 1% ↻ 119h02m│
│────────────────────│
│ extra $0/$200       │
│────────────────────│
│ Refresh             │
│ Quit                │
└────────────────────┘
```

Reads OAuth credentials from Claude Code's keychain entry. Zero config. Zero dependencies. Polls every 2 minutes.

## Requirements

- macOS
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (for OAuth credentials)

## Build & run

```sh
swiftc -O -framework Cocoa -framework Security -o claude-usage claude-usage.swift
./claude-usage
```

## Launch on login

```sh
cp com.claude-usage.plist ~/Library/LaunchAgents/
# edit the path inside the plist to point to your binary
launchctl load ~/Library/LaunchAgents/com.claude-usage.plist
```

## How it works

1. Reads `accessToken` from macOS Keychain (service: `Claude Code-credentials`)
2. Calls `GET https://api.anthropic.com/api/oauth/usage` with `anthropic-beta: oauth-2025-04-20`
3. Renders utilization percentages and reset countdowns in the menu bar

## Benchmarks

```
RSS memory:  46 MB
CPU idle:    0.0%
Poll:        ~710ms (network bound)
Binary:      84K
```
