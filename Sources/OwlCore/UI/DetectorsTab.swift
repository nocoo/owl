import SwiftUI

/// A single row in the detector toggles list.
struct DetectorToggleRow: View {
    let info: DetectorInfo
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.displayName)
                    .font(.system(size: 13))
                Text(info.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }
}

/// Detectors settings tab: toggle each detector on/off.
public struct DetectorsTab: View {
    let detectors: [DetectorInfo]
    @Binding var enabledStates: [String: Bool]

    public init(
        detectors: [DetectorInfo],
        enabledStates: Binding<[String: Bool]>
    ) {
        self.detectors = detectors
        self._enabledStates = enabledStates
    }

    public var body: some View {
        List(detectors) { detector in
            DetectorToggleRow(
                info: detector,
                isEnabled: binding(for: detector.id)
            )
        }
        .listStyle(.inset)
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { enabledStates[id] ?? true },
            set: { enabledStates[id] = $0 }
        )
    }
}
