#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["rumps"]
# ///
"""Claude usage in your menu bar. Reads OAuth creds from Claude Code keychain."""

import json, subprocess, urllib.request, rumps
from datetime import datetime, timezone

LIMITS = [("5h", "five_hour"), ("7d", "seven_day"), ("opus", "seven_day_opus"), ("sonnet", "seven_day_sonnet")]


def token():
    out = subprocess.run(
        ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
        capture_output=True, text=True, check=True,
    ).stdout
    return json.loads(out)["claudeAiOauth"]["accessToken"]


def fetch():
    req = urllib.request.Request(
        "https://api.anthropic.com/api/oauth/usage",
        headers={"Authorization": f"Bearer {token()}", "anthropic-beta": "oauth-2025-04-20"},
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)


def eta(d):
    if not (ts := d.get("resets_at")):
        return ""
    m = max(0, int((datetime.fromisoformat(ts) - datetime.now(timezone.utc)).total_seconds() / 60))
    return f"{m // 60}h{m % 60:02d}m" if m >= 60 else f"{m}m"


class App(rumps.App):
    def __init__(self):
        super().__init__("◇", quit_button="Quit")
        self._items = {k: rumps.MenuItem(k) for k, _ in LIMITS}
        self._extra = rumps.MenuItem("extra")
        self.menu = [*self._items.values(), None, self._extra, None,
                     rumps.MenuItem("Refresh", callback=lambda _: self._poll())]
        self._poll()

    @rumps.timer(120)
    def _tick(self, _):
        self._poll()

    def _poll(self):
        try:
            u = fetch()
            h5 = u.get("five_hour") or {}
            self.title = f"◇ {h5.get('utilization', 0):.0f}%"
            for label, key in LIMITS:
                d = u.get(key) or {}
                p = d.get("utilization")
                self._items[label].title = f"{label} {p:.0f}% ↻ {eta(d)}" if p is not None else f"{label} ·"
            ex = u.get("extra_usage") or {}
            lim = ex.get("monthly_limit", 0)
            self._extra.title = f"extra ${ex.get('used_credits', 0):.0f}/${lim:.0f}" if lim else "extra ·"
        except Exception as e:
            self.title = "◇ !"
            self._items["5h"].title = str(e)[:60]


if __name__ == "__main__":
    App().run()
