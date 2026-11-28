# Binsen (便箋)

[简体中文](README.md) | **English** | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [Español](README.es.md)

Jot down a quick line on your iPhone; seconds later, it quietly appears as a brand-new note in the built-in macOS **Stickies** app.

https://github.com/user-attachments/assets/12b98983-d6f9-4837-83bc-dde8d83b0335

Named after the Japanese word **便箋 (*binsen*, stationery pad)**, Binsen bridges fleeting thoughts on your phone straight onto your Mac desktop—without servers, accounts, open ports, or clipboard clutter.

## Highlights

* **Truly Native**: Writes directly into Apple's built-in **Stickies.app**, not a custom floating-window clone.
* **Zero Interruption**: Never steals window focus while you're typing on your Mac. If Stickies isn't running yet, Binsen launches it quietly and reuses its default blank note—leaving zero extra blank notes behind.
* **Hands Off Your Clipboard**: Leaves your system pasteboard completely untouched.
* **Pure iCloud Sync**: No server, no sign-up, no network listeners. Everything stays in your own iCloud (Reminders or iCloud Drive).
* **Auditable & Minimal**: A single dependency-free Swift file.

## Requirements

* macOS 13 or later
* Xcode or Command Line Tools (`xcode-select --install`)
* Both Mac and iPhone signed into the same Apple Account, with **Reminders** turned on in iCloud (the older file-based shortcut also needs **iCloud Drive**)

## Setup

### 1. Install on Mac

```bash
git clone https://github.com/Qinov5/Binsen.git
cd Binsen
zsh install.sh
```

The installer compiles the app into `~/Applications/Binsen.app`, creates the inbox folder in iCloud Drive, registers a `LaunchAgent` for login startup, and tests both the iCloud Drive and the Reminders channel. Once **`Binsen 已接通 ✅`** and **`Binsen 提醒事项通道已接通 ✅`** pop up in Stickies, you're good to go.

> The installer and log messages are currently in Simplified Chinese only.

### 2. Grant Permission (Recommended)

Allow Binsen to control **Stickies** only:
* **macOS 27.3+**: In the prompt, click **Choose Apps**, add **Stickies**, and set it to **At Any Time** (manageable later under *System Settings → Privacy & Security → System & App Protection Override*).
* **Earlier macOS**: Enable **Binsen** under *System Settings → Privacy & Security → Accessibility* (or *Device Control and Data Access* on early macOS 27 builds).

**Reminders**: during installation macOS asks whether Binsen may access Reminders—click **Allow**. Binsen only reads and writes the **Binsen** list (it creates the list in iCloud if needed) and marks each reminder as completed once it has been pasted. If you missed the prompt, enable Binsen under *System Settings → Privacy & Security → Reminders* and run `zsh install.sh` again.

*Without this permission, Binsen gracefully falls back to the macOS `Make Sticky` system service, which brings Stickies to the front and may leave an extra blank note on cold launch.*

### 3. Add the iPhone Shortcut

The **Reminders** version is recommended: reminders sync right away, and in testing a note showed up on the Mac about 10 seconds after it was sent.

Open **[Add the Binsen Shortcut](https://www.icloud.com/shortcuts/54ba2387d2b54ceebe1437aef3b34d47)** on your iPhone. It shows a text prompt and adds what you type to the **Binsen** reminders list. After adding it, open the shortcut once: if the list isn't **Binsen**, pick it again (the list appears once Binsen is installed on your Mac).

*(Tip: bind it to your iPhone's **Action Button** for instant one-press capture.)*

<details>
<summary>Prefer to build it yourself?</summary>

1. **Ask for Input** (`Text`)
2. **Add New Reminder** — Reminder: *Provided Input*, List: **Binsen** (if it isn't there yet, open the Reminders app once so it syncs)
</details>

<details>
<summary>Older version: save a file to iCloud Drive (can be delayed for a long time)</summary>

Open **[Add the older Binsen Shortcut](https://www.icloud.com/shortcuts/22b6bb3e26b046278a8ee42ee9dd0edd)**, or build it yourself: **Ask for Input** (`Text`) → **Save File** (Input: *Provided Input*, turn off *Ask Where to Save*, Subpath: `/Binsen/`).

> The iPhone often doesn't upload files saved by Shortcuts right away; the upload may not start until you open the Files app, so notes can be minutes or hours late. The Mac still watches this folder, so the older shortcut keeps working.
</details>

## Maintenance

* **Logs**: `tail -20 ~/Library/Logs/Binsen.log`
* **Update**: `git pull && zsh install.sh`
* **Uninstall**: `zsh uninstall.sh` *(your inbox folder, the Binsen reminders list and existing Stickies remain untouched)*

## Troubleshooting

* **A note took a long time to show up**: find the `收到：` (received) line in the log. It records how long iCloud took to deliver it to this Mac, and how long the Mac slept in the meantime. From `收到` to `已贴到便笺` (pasted) usually takes 1–2 seconds, so delays almost always happen in iCloud.
* **Notes sent while the Mac was closed or asleep**: a sleeping Mac can't create notes. Once it wakes, iCloud catches up and the note is pasted on its own, usually within tens of seconds.
* **With the older Save File shortcut, notes don't arrive until you open the Files app**: the iPhone doesn't upload files saved by Shortcuts right away. Switch to the Reminders version above.
* **Still slow with the Mac awake and the note already sent**: a proxy or VPN is probably blocking iCloud push notifications, so the Mac never hears about the change. If Shadowrocket, Clash or a similar tool sets a system proxy, add `*.push.apple.com` and `17.0.0.0/8` to its skip-proxy list.
* **The log says `提醒事项：没有访问权限` (no Reminders access)**: enable Binsen under *System Settings → Privacy & Security → Reminders*, then run `launchctl kickstart -k gui/$(id -u)/io.github.qinov5.binsen`.

## License

[MIT](LICENSE)
