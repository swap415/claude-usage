import Cocoa
import Security

let limits: [(String, String)] = [("5h","five_hour"),("7d","seven_day"),("opus","seven_day_opus"),("sonnet","seven_day_sonnet")]

func readToken() -> String? {
    var result: AnyObject?
    let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "Claude Code-credentials", kSecReturnData as String: true]
    guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let oauth = json["claudeAiOauth"] as? [String: Any],
          let token = oauth["accessToken"] as? String else { return nil }
    return token
}

func eta(_ d: [String: Any]) -> String {
    guard let ts = d["resets_at"] as? String else { return "" }
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = f.date(from: ts) else { return "" }
    let m = max(0, Int(date.timeIntervalSinceNow / 60))
    return m >= 60 ? "\(m/60)h\(String(format:"%02d",m%60))m" : "\(m)m"
}

class App: NSObject, NSApplicationDelegate {
    let bar = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var rows: [String: NSMenuItem] = [:]
    var extra = NSMenuItem()

    func applicationDidFinishLaunching(_ n: Notification) {
        let menu = NSMenu()
        for (label, _) in limits {
            let item = NSMenuItem(title: label, action: nil, keyEquivalent: "")
            rows[label] = item; menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(extra)
        menu.addItem(.separator())
        let refresh = NSMenuItem(title: "Refresh", action: #selector(poll), keyEquivalent: "r")
        refresh.target = self; menu.addItem(refresh)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate), keyEquivalent: "q"))
        bar.menu = menu; bar.button?.title = "◇"
        poll()
        Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { _ in self.poll() }
    }

    @objc func poll() {
        guard let token = readToken() else {
            DispatchQueue.main.async { self.bar.button?.title = "◇ !" }; return
        }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.timeoutInterval = 15
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data, let u = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { self.bar.button?.title = "◇ !" }; return
            }
            DispatchQueue.main.async { self.render(u) }
        }.resume()
    }

    func render(_ u: [String: Any]) {
        let h5 = u["five_hour"] as? [String: Any] ?? [:]
        bar.button?.title = "◇ \(Int(h5["utilization"] as? Double ?? 0))%"
        for (label, key) in limits {
            if let d = u[key] as? [String: Any], let p = d["utilization"] as? Double {
                rows[label]?.title = "\(label) \(Int(p))% ↻ \(eta(d))"
            } else { rows[label]?.title = "\(label) ·" }
        }
        if let ex = u["extra_usage"] as? [String: Any], let lim = ex["monthly_limit"] as? Double, lim > 0 {
            extra.title = "extra $\(Int(ex["used_credits"] as? Double ?? 0))/$\(Int(lim))"
        } else { extra.title = "extra ·" }
    }
}

let delegate = App()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
