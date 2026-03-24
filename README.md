# BurnerMail
![burnermailpicture cropped](https://github.com/user-attachments/assets/62808c84-dfda-4c05-b11e-c99252c84f82)


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

Photos and community server.
https://discord.gg/g4ccFUEcnU

<img width="364" height="250" alt="Screenshot 2026-03-23 at 11 59 49 PM" src="https://github.com/user-attachments/assets/f31bf2c3-cc9b-450f-bae1-f09539da1ac8" />

<img width="336" height="333" alt="Screenshot 2026-03-24 at 12 00 08 AM" src="https://github.com/user-attachments/assets/63326174-f0b1-427e-b946-ca32cd73a8f0" />

<img width="358" height="301" alt="Screenshot 2026-03-24 at 12 01 28 AM" src="https://github.com/user-attachments/assets/26fc2ec6-2df2-4d95-9023-7024fb8d08f0" />




