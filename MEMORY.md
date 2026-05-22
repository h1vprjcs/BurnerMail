# BurnerMail Update Log

A running history of every release: what changed, why, and the corresponding GitHub release / DMG.

---

## v1.0.1 — 2026-05-22

**Fixes**
- **Keychain error -34018 (`errSecMissingEntitlement`)** when saving the generated burner credentials. The app was passing `kSecAttrSynchronizable = true` to `SecItemAdd`, which requires the iCloud Keychain entitlement. Ad-hoc / unsigned builds don't have that entitlement, so the save failed and the UI showed the red error banner.
  - Fix: `KeychainService.save` now tries the iCloud-synced add first and, on `errSecMissingEntitlement`, transparently retries without `kSecAttrSynchronizable`. Signed builds keep syncing to iCloud Keychain; unsigned / ad-hoc builds fall back to the local Keychain. Both show up in the Apple Passwords app.

**Improvements**
- Added a version footer (`BurnerMail v1.0.1 (2)`) at the bottom of the popover, visible on the generate and result screens.

**Build / packaging changes**
- App Sandbox disabled (`ENABLE_APP_SANDBOX = NO`) and the `keychain-access-groups` entitlement removed. These required a provisioning profile + registered bundle ID on the Developer Portal, which blocked third-party rebuilds. The app now uses the default (non-sandboxed) local Keychain, which doesn't need any provisioning profile.
- `release.sh` (project root) now builds with code-signing disabled in Xcode, then strips xattrs and ad-hoc signs after the build to work around iCloud Drive xattrs that otherwise break `codesign`.
- `DEVELOPMENT_TEAM` cleared in `project.pbxproj` (no personal team ID committed to the public repo).
- Version bumped: `MARKETING_VERSION 1.0 → 1.0.1`, `CURRENT_PROJECT_VERSION 1 → 2`.

**Artifacts**
- GitHub release: https://github.com/h1vprjcs/BurnerMail/releases/tag/v1.0.1
- DMG: `BurnerMail-1.0.1.dmg`
- Discord embed: posted to the BurnerMail releases webhook.

---

## v1.0 — 2026-03-26

Initial public release.

- Menu bar app that generates iCloud Hide My Email addresses + strong passwords in one click.
- WebKit-based iCloud sign-in flow (2FA supported).
- Credentials saved to iCloud Keychain so they show up in the Apple Passwords app.
- Launch-at-login toggle in Settings.

Artifacts:
- GitHub release: https://github.com/h1vprjcs/BurnerMail/releases/tag/v1.0
- DMG: `BurnerMail-1.0.dmg`
