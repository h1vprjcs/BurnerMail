import SwiftUI
import WebKit

// MARK: - Auth Sheet

struct AuthSheet: View {
    @EnvironmentObject var iCloudService: iCloudHMEService
    @Binding var isPresented: Bool
    @State private var statusMessage = "Sign in to iCloud, then tap Done"
    @State private var isValidating = false

    // Holds a reference to the WKWebView so the Done button
    // can transfer cookies before validating
    @State private var webViewRef: WKWebView? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect iCloud")
                        .font(.headline)
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isValidating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 6)
                }
                Button("Done") {
                    Task { await validate() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isValidating)

                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            iCloudWebView(
                onWebViewCreated: { wv in
                    webViewRef = wv
                },
                onLoginDetected: { _ in
                    // Auto-detected login - just trigger validate
                    // (cookies already in the shared store from the WebView)
                    Task { await validate() }
                }
            )
            .frame(height: 460)
        }
    }

    // MARK: - Validation

    private func validate() async {
        guard !isValidating else { return }
        isValidating = true
        statusMessage = "Verifying iCloud session..."

        // Always transfer cookies from the WebView first
        if let wv = webViewRef {
            await iCloudService.transferCookies(from: wv)
        }

        do {
            let ok = try await iCloudService.validateSession()
            if ok {
                isPresented = false
                return
            } else {
                statusMessage = "Not signed in yet - complete login and tap Done"
            }
        } catch HMEError.hmeServiceUnavailable {
            statusMessage = "iCloud+ required for Hide My Email"
        } catch {
            statusMessage = "Could not verify - tap Done after signing in"
        }

        isValidating = false
    }
}

// MARK: - WKWebView wrapper

private struct iCloudWebView: NSViewRepresentable {
    var onWebViewCreated: (WKWebView) -> Void
    var onLoginDetected: (WKWebView) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: URL(string: "https://www.icloud.com")!))

        // Pass the reference up immediately so Done button can use it
        DispatchQueue.main.async { onWebViewCreated(webView) }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoginDetected: onLoginDetected)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onLoginDetected: (WKWebView) -> Void
        private var fired = false

        init(onLoginDetected: @escaping (WKWebView) -> Void) {
            self.onLoginDetected = onLoginDetected
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !fired else { return }
            guard let url = webView.url?.absoluteString else { return }

            let onAuthPage = url.contains("idmsa.apple.com")
                          || url.contains("appleid.apple.com")
                          || url.contains("/sign-in")
                          || url.contains("/auth/")

            guard url.hasPrefix("https://www.icloud.com"), !onAuthPage else { return }

            // Wait a moment for cookies to settle, then auto-trigger
            fired = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.onLoginDetected(webView)
            }
        }
    }
}
