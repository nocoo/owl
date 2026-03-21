import Foundation

/// P05 — Sandbox Violation Storm pattern configuration.
///
/// Detects applications generating excessive sandbox deny events.
/// Uses SignatureDetector with explicit capture group mapping and target normalization.
///
/// Matches both `Sandbox:` and `System Policy:` prefixed deny messages
/// from the kernel log stream.
///
/// - Regex: extracts process name, operation, and target from deny messages
/// - Window: 60 seconds
/// - Warning: 10 distinct signatures/window per process
/// - Critical: 50 distinct signatures/window per process
/// - Cooldown: 300 seconds
public enum SandboxPattern {

    public static let id = "sandbox_violation_storm"

    public static func makeDetector() -> SignatureDetector {
        SignatureDetector(config: SignatureConfig(
            id: id,
            regex: #"(?:Sandbox|System Policy):\s+(.+?)\(\d+\)\s+deny\(1\)\s+(\S+)\s+(.+)$"#,
            keyGroupIndex: 1,
            signatureGroupIndexes: [2, 3],
            windowSeconds: 60,
            warningDistinct: 10,
            criticalDistinct: 50,
            cooldownInterval: 300,
            maxGroups: 50,
            titleKey: .alertSandboxTitle,
            descriptionTemplateKey: .alertSandboxDesc("{key}", "{window}", "{count}"),
            suggestionKey: .alertSandboxSuggestion,
            acceptsFilter: "deny(1)"
        ) { target in normalizeTarget(target) })
    }

    static func normalizeTarget(_ target: String) -> String {
        var normalized = target
            .replacingOccurrences(
                of: #"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b"#,
                with: "<UUID>",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?<=^|/|=|:|\.)\d+(?=$|/|\.|:)"#,
                with: "<N>",
                options: .regularExpression
            )

        if normalized.hasPrefix("/private/var/folders/") {
            var components = normalized.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            if components.count > 5 {
                components[4] = "<ID>"
                components[5] = "<ID>"
            }
            if components.count > 6, components[6].allSatisfy(\.isNumber) {
                components[6] = "<N>"
            }

            normalized = components.joined(separator: "/")
        }

        guard normalized.hasPrefix("/") else { return normalized }

        let parts = normalized.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !parts.isEmpty else { return normalized }

        if parts.starts(with: ["private", "var", "folders"]), parts.count > 6 {
            let stableRoot = Array(parts.prefix(7))
            return "/" + stableRoot.joined(separator: "/")
        }

        return "/" + Array(parts.prefix(2)).joined(separator: "/")
    }
}
