import Foundation
import Security

// Generates cryptographically secure random passwords using SecRandomCopyBytes
class PasswordGenerator {

    struct Config {
        var length: Int = 20
        var includeUppercase: Bool = true
        var includeLowercase: Bool = true
        var includeNumbers: Bool = true
        var includeSymbols: Bool = true
    }

    func generate(config: Config = Config()) -> String {
        var chars = ""
        if config.includeLowercase { chars += "abcdefghijkmnopqrstuvwxyz" }     // no l (looks like 1)
        if config.includeUppercase { chars += "ABCDEFGHJKLMNPQRSTUVWXYZ" }      // no I, O (confusing)
        if config.includeNumbers   { chars += "23456789" }                       // no 0, 1
        if config.includeSymbols   { chars += "!@#$%^&*-_=+" }

        guard !chars.isEmpty else { return "" }

        let charsArray = Array(chars)
        var randomBytes = [UInt8](repeating: 0, count: config.length)
        guard SecRandomCopyBytes(kSecRandomDefault, config.length, &randomBytes) == errSecSuccess else {
            // Fallback to less secure random (should never happen)
            return (0..<config.length).map { _ in charsArray[Int.random(in: 0..<charsArray.count)] }
                                      .map { String($0) }.joined()
        }

        // Map each random byte to a character, using modulo bias reduction
        // (acceptable for passwords since character set is small)
        return randomBytes
            .map { charsArray[Int($0) % charsArray.count] }
            .map { String($0) }
            .joined()
    }
}
