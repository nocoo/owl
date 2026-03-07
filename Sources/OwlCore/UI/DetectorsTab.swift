import SwiftUI

/// A single row in the detector toggles list.
struct DetectorToggleRow: View {
    let info: DetectorInfo
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.displayName)
                    .font(.system(size: 14))
                Text(info.description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }
}

/// Detectors settings tab: toggle each detector on/off, grouped.
public struct DetectorsTab: View {
    @Binding var enabledStates: [String: Bool]

    public init(
        enabledStates: Binding<[String: Bool]>
    ) {
        self._enabledStates = enabledStates
    }

    public var body: some View {
        List {
            ForEach(
                DetectorCatalog.grouped,
                id: \.0
            ) { category, detectors in
                Section {
                    ForEach(detectors) { detector in
                        DetectorToggleRow(
                            info: detector,
                            isEnabled: binding(
                                for: detector.id
                            )
                        )
                    }
                } header: {
                    Label(
                        category.rawValue,
                        systemImage: category.symbolName
                    )
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func binding(
        for id: String
    ) -> Binding<Bool> {
        Binding(
            get: { enabledStates[id] ?? true },
            set: { enabledStates[id] = $0 }
        )
    }
}
