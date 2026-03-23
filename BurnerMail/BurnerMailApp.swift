import SwiftUI

// MARK: - App Entry Point
// Requires macOS 13 (Ventura) or later for MenuBarExtra.
// The app lives entirely in the menu bar - no Dock icon.

@main
struct BurnerMailApp: App {
    @StateObject private var iCloudService = iCloudHMEService.shared

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(iCloudService)
        } label: {
            // Shows in the menu bar. System tint changes when authenticated.
            Label {
                Text("BurnerMail")
            } icon: {
                Image(systemName: iCloudService.isAuthenticated
                      ? "envelope.badge.shield.half.filled"
                      : "envelope.badge.shield.half.filled.fill")
            }
        }
        .menuBarExtraStyle(.window)   // Shows a floating panel (not a classic menu)
    }
}
