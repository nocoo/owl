import Foundation

/// P06 — Sleep Assertion Leak pattern configuration.
///
/// Detects unreleased sleep prevention assertions by tracking Created/Released
/// pairs from powerd. Uses StateDetector with pair matching on assertion ID.
///
/// - Created regex: extracts assertion ID, type, and source
/// - Released regex: extracts assertion ID for pairing
/// - Warning age: 1800s (30 minutes)
/// - Critical age: 7200s (2 hours)
/// - Max tracked: 100 unpaired assertions
public enum SleepAssertionPattern {

    public static let id = "sleep_assertion_leak"

    public static func makeDetector() -> StateDetector {
        StateDetector(config: StateConfig(
            id: id,
            // Groups: (1)=assertion ID, (2)=assertion type, (3)=source
            // Uses lookahead to capture id (at end of message) as group 1
            createdRegex: #"(?=.*id:(0x[0-9a-fA-F]+))Created\s+(\S+)\s+"([^"]+)""#,
            releasedRegex: #"Released\s+\S+\s+"[^"]*".*?id:(0x[0-9a-fA-F]+)"#,
            warningAge: 1800,
            criticalAge: 7200,
            maxTracked: 100,
            titleKey: .alertSleepTitle,
            descriptionTemplateKey: .alertSleepDesc("{id}", "{type}", "{source}", "{age}"),
            suggestionKey: .alertSleepSuggestion,
            acceptsFilter: "PreventSleep"
        ))
    }
}
