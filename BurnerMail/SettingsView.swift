import SwiftUI
import ServiceManagement

// MARK: - Settings View

struct SettingsView: View {
    @Binding var isPresented: Bool
    @State private var launchAtLogin: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Back")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider()

            VStack(spacing: 0) {
                // Launch at Login row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(.system(size: 13))
                        Text("Open BurnerMail automatically when you log in.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { newValue in
                            setLaunchAtLogin(enabled: newValue)
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal, 14)
            .padding(.top, 12)

            Spacer(minLength: 16)

            // App version footer
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("BurnerMail v\(version)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 14)
            }
        }
        .onAppear {
            launchAtLogin = isLaunchAtLoginEnabled()
        }
    }

    // MARK: - Launch at Login Helpers

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // If registration fails, revert the toggle
                DispatchQueue.main.async {
                    launchAtLogin = isLaunchAtLoginEnabled()
                }
            }
        }
    }
}
