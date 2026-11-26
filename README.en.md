# Binsen (便箋)

[简体中文](README.md) | **English** | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [Español](README.es.md)

Jot down a quick line on your iPhone; seconds later, it quietly appears as a brand-new note in the built-in macOS **Stickies** app.

https://github.com/user-attachments/assets/12b98983-d6f9-4837-83bc-dde8d83b0335

Named after the Japanese word **便箋 (*binsen*, stationery pad)**, Binsen bridges fleeting thoughts on your phone straight onto your Mac desktop—without servers, accounts, open ports, or clipboard clutter.

## Highlights

* **Truly Native**: Writes directly into Apple's built-in **Stickies.app**, not a custom floating-window clone.
* **Zero Interruption**: Never steals window focus while you're typing on your Mac. If Stickies isn't running yet, Binsen launches it quietly and reuses its default blank note—leaving zero extra blank notes behind.
* **Hands Off Your Clipboard**: Leaves your system pasteboard completely untouched.
* **Pure iCloud Sync**: No server, no sign-up, no network listeners. Everything stays in your own iCloud Drive.
* **Auditable & Minimal**: A single dependency-free Swift file.

## Requirements

* macOS 13 or later
* Xcode or Command Line Tools (`xcode-select --install`)
* Both Mac and iPhone signed into the same Apple Account with **iCloud Drive** enabled

## Setup

### 1. Install on Mac

```bash
git clone https://github.com/Qinov5/Binsen.git
cd Binsen
zsh install.sh
```

The installer compiles the app into `~/Applications/Binsen.app`, creates the inbox folder in iCloud Drive, registers a `LaunchAgent` for login startup, and drops a test message. Once **`Binsen 已接通 ✅`** pops up in Stickies, you're good to go.

> The installer and log messages are currently in Simplified Chinese only.

### 2. Grant Permission (Recommended)

Allow Binsen to control **Stickies** only:
* **macOS 27.3+**: In the prompt, click **Choose Apps**, add **Stickies**, and set it to **At Any Time** (manageable later under *System Settings → Privacy & Security → System & App Protection Override*).
* **Earlier macOS**: Enable **Binsen** under *System Settings → Privacy & Security → Accessibility* (or *Device Control and Data Access* on early macOS 27 builds).

*Without this permission, Binsen gracefully falls back to the macOS `Make Sticky` system service, which brings Stickies to the front and may leave an extra blank note on cold launch.*

### 3. Add the iPhone Shortcut

Open **[Add the Binsen Shortcut](https://www.icloud.com/shortcuts/22b6bb3e26b046278a8ee42ee9dd0edd)** on your iPhone and tap **Add Shortcut** *(Tip: bind it to your iPhone's **Action Button** for instant one-press capture)*.

Or build it yourself with just two actions:
1. **Ask for Input** (`Text`)
2. **Save File** — Input: *Provided Input*, toggle off *Ask Where to Save*, Subpath: `/Binsen/`

## Maintenance

* **Logs**: `tail -20 ~/Library/Logs/Binsen.log`
* **Update**: `git pull && zsh install.sh`
* **Uninstall**: `zsh uninstall.sh` *(your inbox folder and existing Stickies remain untouched)*

## License

[MIT](LICENSE)
