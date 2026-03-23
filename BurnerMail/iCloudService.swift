import Foundation
import Combine
import WebKit

// MARK: - Error Type

enum HMEError: LocalizedError {
    case notAuthenticated
    case sessionExpired
    case hmeServiceUnavailable
    case requestFailed(Int, String)
    case apiFailed(String)
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please connect your iCloud account first."
        case .sessionExpired:
            return "Your iCloud session expired. Please reconnect."
        case .hmeServiceUnavailable:
            return "Hide My Email requires iCloud+ (any paid plan). Check System Settings > Apple ID."
        case .requestFailed(let code, let body):
            return "HTTP \(code) from iCloud.\n\(body.prefix(120))"
        case .apiFailed(let msg):
            return "iCloud error: \(msg)"
        case .decodeFailed(let body):
            return "Unexpected iCloud response:\n\(body.prefix(200))"
        }
    }
}

// MARK: - iCloud Hide My Email Service

@MainActor
class iCloudHMEService: ObservableObject {
    static let shared = iCloudHMEService()
    private init() {}

    @Published var isAuthenticated = false

    private var hmeBaseURL: String?
    private let hmeBaseURLKey = "com.burnermail.hmeBaseURL"

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        return URLSession(configuration: config)
    }()

    // MARK: - Cookie Bridging

    func transferCookies(from webView: WKWebView) async {
        let cookies = await withCheckedContinuation { continuation in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies {
                continuation.resume(returning: $0)
            }
        }
        NSLog("BurnerMail: transferring \(cookies.count) cookies from WebView")
        for cookie in cookies {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    // MARK: - Session Validation

    @discardableResult
    func validateSession() async throws -> Bool {
        guard let url = URL(string: "https://setup.icloud.com/setup/ws/1/validate") else {
            return false
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = Data("{}".utf8)
        applyHeaders(to: &req)

        let (data, response) = try await session.data(for: req)
        let body = String(data: data, encoding: .utf8) ?? ""
        NSLog("BurnerMail validate status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        NSLog("BurnerMail validate body: \(body.prefix(500))")

        guard let http = response as? HTTPURLResponse else { return false }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 || http.statusCode == 403 { isAuthenticated = false }
            return false
        }

        // Parse the response with JSONSerialization for maximum flexibility
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        // Find the HME service URL - search common key names Apple has used
        let hmeURL = findHMEServiceURL(in: json)
        NSLog("BurnerMail HME service URL: \(hmeURL ?? "not found")")

        guard let hmeURL else {
            isAuthenticated = false
            throw HMEError.hmeServiceUnavailable
        }

        hmeBaseURL = hmeURL
        UserDefaults.standard.set(hmeURL, forKey: hmeBaseURLKey)
        isAuthenticated = true
        return true
    }

    /// Searches the validate response JSON for the premium mail / HME service URL.
    /// Apple has used different key names over time so we try all known variants.
    private func findHMEServiceURL(in json: [String: Any]) -> String? {
        guard let webservices = json["webservices"] as? [String: Any] else { return nil }

        // Known key names (Apple occasionally renames these)
        let candidateKeys = [
            "premiummailsettings",
            "premiummaildomainsettings",
            "hidemyemail",
            "mail"
        ]

        for key in candidateKeys {
            if let svc = webservices[key] as? [String: Any],
               let url = svc["url"] as? String,
               !url.isEmpty {
                let status = svc["status"] as? String ?? "active"
                if status == "active" || status == "enabled" {
                    return url
                }
            }
        }

        // Fallback: find any webservice entry that looks like a mail domain URL
        for (_, value) in webservices {
            if let svc = value as? [String: Any],
               let url = svc["url"] as? String,
               url.contains("maildomainws") || url.contains("mail") {
                return url
            }
        }

        return nil
    }

    // MARK: - Generate + Reserve

    func generateEmail() async throws -> String {
        let base = try requireBaseURL()
        guard let url = URL(string: "\(base)/v1/hme/generate") else {
            throw HMEError.apiFailed("Invalid HME URL: \(base)")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = Data("{}".utf8)
        applyHeaders(to: &req)

        let (data, response) = try await session.data(for: req)
        let body = String(data: data, encoding: .utf8) ?? ""
        NSLog("BurnerMail generate status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        NSLog("BurnerMail generate body: \(body.prefix(500))")

        guard let http = response as? HTTPURLResponse else {
            throw HMEError.decodeFailed("No HTTP response")
        }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 || http.statusCode == 403 {
                isAuthenticated = false
                throw HMEError.sessionExpired
            }
            throw HMEError.requestFailed(http.statusCode, body)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HMEError.decodeFailed(body)
        }

        // Check for API-level error first
        if let success = json["success"] as? Bool, !success {
            let msg = (json["error"] as? [String: Any])?["errorMessage"] as? String
                   ?? json["reason"] as? String
                   ?? "Generate failed"
            throw HMEError.apiFailed(msg)
        }

        // Extract hme from result object
        if let result = json["result"] as? [String: Any], let hme = result["hme"] as? String {
            return hme
        }

        // Fallback: hme at top level
        if let hme = json["hme"] as? String { return hme }

        throw HMEError.decodeFailed(body)
    }

    func reserveEmail(_ hme: String, label: String, note: String = "") async throws -> String {
        let base = try requireBaseURL()
        guard let url = URL(string: "\(base)/v1/hme/reserve") else {
            throw HMEError.apiFailed("Invalid HME URL: \(base)")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        applyHeaders(to: &req)
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "hme": hme,
            "label": label.isEmpty ? "Burner" : label,
            "note": note
        ])

        let (data, response) = try await session.data(for: req)
        let body = String(data: data, encoding: .utf8) ?? ""
        NSLog("BurnerMail reserve status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        NSLog("BurnerMail reserve body: \(body.prefix(500))")

        guard let http = response as? HTTPURLResponse else {
            throw HMEError.decodeFailed("No HTTP response")
        }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 || http.statusCode == 403 {
                isAuthenticated = false
                throw HMEError.sessionExpired
            }
            throw HMEError.requestFailed(http.statusCode, body)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HMEError.decodeFailed(body)
        }

        if let success = json["success"] as? Bool, !success {
            let msg = (json["error"] as? [String: Any])?["errorMessage"] as? String ?? "Reserve failed"
            throw HMEError.apiFailed(msg)
        }

        // The reserve response wraps hme inside result.hme as an object:
        // {"result": {"hme": {"hme": "actual@icloud.com", ...}}}
        if let result = json["result"] as? [String: Any] {
            // Nested object: result.hme.hme
            if let hmeObj = result["hme"] as? [String: Any],
               let addr = hmeObj["hme"] as? String, !addr.isEmpty {
                return addr
            }
            // Flat string: result.hme
            if let addr = result["hme"] as? String, !addr.isEmpty {
                return addr
            }
        }
        // Fall back to the generated address we already have
        return hme
    }

    func generateAndReserve(label: String) async throws -> String {
        let hme = try await generateEmail()
        return try await reserveEmail(hme, label: label)
    }

    // MARK: - Sign Out

    func signOut() {
        isAuthenticated = false
        hmeBaseURL = nil
        UserDefaults.standard.removeObject(forKey: hmeBaseURLKey)
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
    }

    // MARK: - Helpers

    private func requireBaseURL() throws -> String {
        if let base = hmeBaseURL { return base }
        if let stored = UserDefaults.standard.string(forKey: hmeBaseURLKey) {
            hmeBaseURL = stored
            return stored
        }
        throw HMEError.notAuthenticated
    }

    private func applyHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://www.icloud.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.icloud.com/", forHTTPHeaderField: "Referer")
    }
}
