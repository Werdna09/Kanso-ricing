<div align="center">

# K A N S O

### 簡素 · The art of less.

**A quiet desktop. Four spaces. One continuous landscape.**

*An independently built desktop setup for KDE Plasma 6 and Wayland.*

**C++20** · **Qt / QML** · **Quickshell** · **KWin** · **CMake** · **CachyOS**

[Philosophy](#philosophy) · [Features](#features) · [Architecture](#architecture) · [Build](#build-and-try) · [Artwork & credits](#artwork--credits)

</div>

---

> **A desktop is a place, not a dashboard.** Kanso is inspired by Japanese minimalism: plenty of breathing room, a small number of carefully chosen colors, and controls that stay out of the way until they're needed.

## Philosophy

Kanso (簡素) is about keeping the useful parts and removing the noise. The panel shows what's worth knowing at a glance. The dock sits quietly at the edge of the screen. Four virtual desktops share one continuous landscape.

Kanso doesn't replace Plasma or KWin. It uses them. The shell is built with **Quickshell and QML**, with a small **C++20** executable handling system information and actions. Window management, desktop effects and the Wayland session remain KDE's job.

## Features

| | Design | Implementation |
|:--|:--|:--|
| **01** | **Four connected workspaces** | KWin virtual desktops and a custom Plasma wallpaper plugin |
| **02** | **Day / Night** | Coordinated KDE colors, terminal, Firefox, VS Code and lock-screen appearance |
| **03** | **Quiet top panel** | Quickshell / QML controls for network, Bluetooth, audio, media, updates, notifications and system information |
| **04** | **Discreet dock** | Auto-reveal behavior, running-app indicators and window previews |
| **05** | **Native system core** | C++20 system status, keyboard locks, launcher, power actions, updates, window picker and icon management |
| **06** | **Personalized workflow** | Rofi, Alacritty, Fish, Neovim and application theme integrations |

### Designed to stay out of the way

- Four workspace indicators and KWin's native transitions.
- A dock that appears when you need it, without moving the layout around.
- Day and Night modes, including an automatic time-based option.
- Update notifications with a deliberate, interactive update flow.
- No Python process required for the running panel, launcher or theme switching.

## Architecture

```text
┌─────────────────────────────────────────────────────┐
│                    KANSO UI                         │
│             Quickshell · Qt · QML                   │
│       Panel · Dock · Menus · Popups                │
└───────────────────────┬─────────────────────────────┘
                        │ processes / JSON
┌───────────────────────▼─────────────────────────────┐
│                 kanso-native                        │
│                C++20 · CMake                       │
│    Status · Themes · Icons · Windows · Actions      │
└───────────────────────┬─────────────────────────────┘
                        │ Linux /proc, /sys, KDE tools
┌───────────────────────▼─────────────────────────────┐
│           CachyOS / KDE Plasma 6 / KWin             │
│            Wayland · D-Bus · systemd                │
└─────────────────────────────────────────────────────┘

       KDE Wallpaper Plugin → panoramic workspace
```

The native core is an **on-demand executable**, not a permanently running service. Quickshell calls it when it needs system data or has an action to perform.

<details>
<summary><strong>Why is there still an install.py?</strong></summary>

`install.py` is the one Python script intentionally kept in the source tree. It is a standalone, setup-time installer, not part of the running desktop. The panel, Day/Night synchronization, launcher and system actions use C++20 and QML.

This is a personal project, and a few older administrative features have not been carried over: the former Python-based tools for initial login configuration, some application themes and their restore workflows are **not included** in this native release. Existing configurations can still be used, but this isn't a drop-in replacement for every old maintenance command.

</details>

## Build and try

**Target:** CachyOS / Arch Linux, KDE Plasma 6, Wayland, Quickshell, a C++20 compiler, CMake and OpenSSL development libraries. Some features also use Rofi, Alacritty, `kdotool`, `qdbus6`, `brightnessctl`, `checkupdates` and `paru`.

Kanso is my desktop configuration, shared as source rather than a universal installer. It expects to live in `~/Rice/kanso`. Back up your existing KDE and Quickshell settings first, and don't run a second Quickshell panel alongside it.

```bash
# Get the source
mkdir -p ~/Projects ~/Rice
git clone https://github.com/Werdna09/Kanso-ricing.git ~/Projects/Kanso-ricing

# Install the shell files into ~/Rice/kanso.
# The installer refuses to replace an existing installation by default.
python3 ~/Projects/Kanso-ricing/kanso/install.py

# Build the native command-line core (no sudo needed)
cmake -S ~/Rice/kanso/native -B ~/Rice/kanso/native/build \
  -DCMAKE_BUILD_TYPE=Release
cmake --build ~/Rice/kanso/native/build --parallel 2
install -Dm755 ~/Rice/kanso/native/build/kanso-native \
  ~/Rice/kanso/native/bin/kanso-native

# Check the native core
~/Rice/kanso/native/bin/kanso-native status
~/Rice/kanso/native/bin/kanso-native doctor preflight
~/Rice/kanso/native/bin/kanso-native doctor audit

# Install the wallpaper plugin code
mkdir -p ~/.local/share/plasma/wallpapers
cp -a ~/Projects/Kanso-ricing/wallpaper/org.kanso.livinglandscape \
  ~/.local/share/plasma/wallpapers/

# Select the installed Living Landscape wallpaper in KDE, then start the shell:
qs -p ~/Rice/kanso
```

**Wallpaper files are included in this release.** The original illustrations are by Artzeene; I combined them into a continuous panorama and prepared the matching Night version. See [ARTWORK.md](ARTWORK.md) for attribution and artwork rights. These assets are separate from the source code and must not be treated as freely licensed simply because they are on GitHub.

The installer only copies the Kanso shell. The wallpaper plugin and any system-wide settings must be configured separately; nothing is silently changed for you.

### Native commands

```bash
# Replace this prefix with ~/Rice/kanso/native/bin/kanso-native
kanso-native status                   # CPU / RAM information
kanso-native locks                    # Caps / Num Lock status
kanso-native rofi                     # application launcher
kanso-native windows                  # native window picker
kanso-native icons status             # inspect installed Kanso icons
kanso-native shortcut audit           # inspect launcher registration
kanso-native updates --print          # show update command without running it
kanso-native power reboot --dry-run   # inspect a power action; do not reboot
kanso-native doctor audit             # check for leftover Python references
```

Power actions in the interface require confirmation. The native executable builds without root privileges.

## Repository map

```text
Kanso-ricing/
├── kanso/
│   ├── shell.qml                 Quickshell entry point
│   ├── components/              Panel, dock and common widgets
│   ├── popups/                  Menus and desktop controls
│   ├── services/                Data and KDE integrations
│   ├── native/
│   │   ├── src/                 C++20 implementation
│   │   └── CMakeLists.txt       Native build
│   ├── config/                  Application appearance
│   ├── icon-theme/              Kanso SVG icon theme
│   └── install.py               Optional Python setup script
├── wallpaper/
│   └── org.kanso.livinglandscape/  KDE wallpaper plugin and panorama assets
├── ARTWORK.md                   Artwork credit and setup notes
└── README.md
```

## Artwork & credits

**The original wallpapers are paid artwork by Artzeene.** I assembled those images into a four-workspace panorama and made a matching night treatment for my personal setup. **The illustrations themselves belong to Artzeene**, not to this project.

The wallpaper assets **are included** in this release. They are not my original illustrations and are not automatically open-source or free to redistribute. Permission to bundle the originals and modified panoramas must come from the artist's license or explicit authorization; a purchase and an attribution alone do not supply that permission. See [ARTWORK.md](ARTWORK.md) for the individual asset paths and rights information.

Kanso is an independent desktop customization project, not affiliated with Artzeene, KDE, Quickshell or CachyOS. Third-party icons and application resources retain their own rights; please check the relevant licenses before redistributing them.

## Contributing

Bug reports and useful suggestions are welcome. If you change the UI, try to keep its spacing and KWin behavior intact. Please don't add third-party artwork without permission to redistribute it, or include personal settings, tokens or backups in contributions.

The repository does not currently include a general-purpose software license. Source availability alone does not grant permission to redistribute or relicense its contents.

---

<div align="center">

**簡素** · *Keep what matters. Leave room for everything else.*

Made with care for quiet desktops.

</div>
