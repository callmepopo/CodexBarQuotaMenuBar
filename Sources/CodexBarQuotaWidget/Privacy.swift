import Foundation

enum Privacy {
    static func maskedEmail(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "Codex 账号"
        }

        let parts = value.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return "***"
        }

        let name = parts[0]
        let domain = parts[1]
        let visiblePrefix = String(name.prefix(2))
        let visibleDomain = String(domain.prefix(1))
        let suffix = domain.contains(".") ? "." + (domain.split(separator: ".").last.map(String.init) ?? "") : ""
        return "\(visiblePrefix)***@\(visibleDomain)***\(suffix)"
    }
}
