import SwiftUI
import AppKit

// MARK: - Main Popover View

struct ContentView: View {
    @EnvironmentObject var iCloudService: iCloudHMEService

    @State private var websiteInput = ""
    @State private var isGenerating = false
    @State private var generatedEmail: String?
    @State private var generatedPassword: String?
    @State private var errorMessage: String?
    @State private var showingAuth = false
    @State private var copiedEmail = false
    @State private var copiedPassword = false
    @State private var showPassword = false

    private let passwordGen = PasswordGenerator()
    private let keychain = KeychainService.shared

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            Group {
                if showingAuth {
                    AuthSheet(isPresented: $showingAuth)
                        .environmentObject(iCloudService)
                } else if !iCloudService.isAuthenticated {
                    notConnectedView
                } else if let email = generatedEmail, let pass = generatedPassword {
                    resultView(email: email, password: pass)
                } else {
                    generateView
                }
            }
            .animation(.easeInOut(duration: 0.18), value: iCloudService.isAuthenticated)
            .animation(.easeInOut(duration: 0.18), value: showingAuth)
            .animation(.easeInOut(duration: 0.18), value: generatedEmail)
        }
        .frame(width: showingAuth ? 480 : 320)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            // Attempt to restore a saved session on launch
            if !iCloudService.isAuthenticated {
                _ = try? await iCloudService.validateSession()
            }
        }
    }

    // MARK: - Header

    var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .foregroundStyle(.blue)
                .font(.system(size: 15, weight: .medium))
            Text("BurnerMail")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            if iCloudService.isAuthenticated && generatedEmail != nil {
                Button(action: resetState) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Generate another")
            }

            if iCloudService.isAuthenticated {
                Button(action: { iCloudService.signOut() }) {
                    Image(systemName: "person.crop.circle.badge.minus")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Disconnect iCloud")
            }

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit BurnerMail")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Not Connected

    var notConnectedView: some View {
        VStack(spacing: 18) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("iCloud not connected")
                    .font(.headline)

                Text("Sign in to use Hide My Email. You need an iCloud+ plan (any paid tier).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Connect iCloud") {
                showingAuth = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
    }

    // MARK: - Generate View

    var generateView: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Label("Website or app name", systemImage: "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("e.g. Netflix, Reddit, Discord...", text: $websiteInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await generate() } }
            }

            if let error = errorMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .background(Color.red.opacity(0.08))
                .cornerRadius(6)
            }

            Button(action: {
                Task { await generate() }
            }) {
                HStack(spacing: 6) {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(isGenerating ? "Creating burner account..." : "Generate Burner Account")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isGenerating)

            Text("Creates a Hide My Email address + strong password, then saves both to Apple Passwords.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
    }

    // MARK: - Result View

    func resultView(email: String, password: String) -> some View {
        VStack(spacing: 12) {
            // Success banner
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Saved to Apple Passwords")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            }
            .padding(.top, 4)

            if !websiteInput.isEmpty {
                Text(websiteInput)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Credentials
            VStack(spacing: 10) {
                credentialRow(
                    label: "Email (Hide My Email)",
                    value: email,
                    icon: "envelope.fill",
                    isCopied: copiedEmail
                ) {
                    copyToClipboard(email)
                    withAnimation { copiedEmail = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copiedEmail = false }
                    }
                }

                passwordRow(password: password)
            }

            Divider()

            HStack {
                Button(action: resetState) {
                    Label("New Burner", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Spacer()

                Button(action: openPasswordsApp) {
                    Label("Add to Passwords", systemImage: "plus.rectangle.on.folder")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)
        }
        .padding(16)
    }

    func credentialRow(
        label: String,
        value: String,
        icon: String,
        isCopied: Bool,
        masked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)

            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button(action: action) {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.caption2)
                    }
                    .foregroundStyle(isCopied ? .green : .blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(7)
        }
    }

    // Password row with tap-to-reveal toggle
    func passwordRow(password: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Password")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.4)
                Spacer()
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showPassword.toggle() } }) {
                    HStack(spacing: 3) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 10))
                        Text(showPassword ? "Hide" : "Reveal")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                if showPassword {
                    Text(password)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .transition(.opacity)
                } else {
                    Text(String(repeating: "•", count: min(password.count, 20)))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .transition(.opacity)
                }

                Spacer()

                Button(action: {
                    copyToClipboard(password)
                    withAnimation { copiedPassword = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copiedPassword = false }
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: copiedPassword ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(copiedPassword ? "Copied" : "Copy")
                            .font(.caption2)
                    }
                    .foregroundStyle(copiedPassword ? .green : .blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(7)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) { showPassword.toggle() }
            }
        }
    }

    // MARK: - Actions

    func generate() async {
        guard !isGenerating else { return }

        await MainActor.run {
            isGenerating = true
            errorMessage = nil
        }

        do {
            let label = websiteInput.trimmingCharacters(in: .whitespaces)
            let email = try await iCloudService.generateAndReserve(
                label: label.isEmpty ? "Burner" : label
            )
            let password = passwordGen.generate()

            try keychain.save(
                website: label,
                username: email,
                password: password
            )

            await MainActor.run {
                generatedEmail = email
                generatedPassword = password
                isGenerating = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isGenerating = false
            }
        }
    }

    func resetState() {
        generatedEmail = nil
        generatedPassword = nil
        errorMessage = nil
        websiteInput = ""
        showPassword = false
    }

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func openPasswordsApp() {
        // Copy the password to clipboard first so the user can paste it in
        if let pass = generatedPassword {
            copyToClipboard(pass)
        }
        // Open Passwords.app - click "+" there and paste the password
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Passwords.app"))
    }
}
