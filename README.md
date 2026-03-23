# BurnerMail

A macOS menu bar app that generates iCloud Hide My Email addresses with strong passwords in one click.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![iCloud+](https://img.shields.io/badge/requires-iCloud%2B-lightblue)

## What it does

1. Click the menu bar icon
2. Type a website name (e.g. "Netflix")
3. Hit **Generate Burner Account**
4. Get a unique `@icloud.com` Hide My Email address + strong random password instantly

The email forwards to your real inbox. The website never knows who you are.

---

## Install (no Xcode needed)

1. Download **BurnerMail-1.0.dmg** from [Releases](../../releases)
2. Open the DMG and drag BurnerMail into Applications
3. **First launch:** right-click BurnerMail > **Open** (macOS security prompt — only needed once)
4. Click the ✉️ icon in your menu bar

### Requirements
- macOS 13 Ventura or later
- An **iCloud+ subscription** (any paid tier — $0.99/month works)
- iCloud Keychain enabled (System Settings > Apple ID > iCloud > Passwords & Keychain)

---

## First-time setup

On first launch BurnerMail will ask you to connect your iCloud account. A browser window opens — sign in normally (2FA works). After that it remembers your session.

---

## Build from source

Requires Xcode 15+ and a free Apple Developer account.

1. Clone the repo
2. Open `BurnerMail.xcodeproj` in Xcode
3. Go to **Signing & Capabilities** and select your Team
4. Press **Cmd+R**

To build a distributable DMG:
```bash
./package-dmg.sh --team YOUR_TEAM_ID
```
The DMG will be at `dist/BurnerMail-1.0.dmg`.

---

## How it works

BurnerMail uses the same private API that iCloud.com uses in your browser to create Hide My Email addresses. After you sign in, it calls `/v1/hme/generate` and `/v1/hme/reserve` to create and save the alias to your iCloud account.

Passwords are generated using `SecRandomCopyBytes` (cryptographically secure) and saved to your Mac's Keychain.

---

## Privacy

- Your Apple ID password is never seen or stored by BurnerMail
- Sign-in happens entirely in a standard WebKit browser view
- No analytics, no telemetry, no servers — the app talks only to Apple's iCloud API
