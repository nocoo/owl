import SwiftUI

/// Bottom bar with Settings and Quit buttons.
public struct BottomBar: View {
    let onSettings: () -> Void
    let onQuit: () -> Void

    public init(
        onSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onSettings = onSettings
        self.onQuit = onQuit
    }

    public var body: some View {
        HStack {
            Button(action: onSettings) {
                Label("Settings", systemImage: "gearshape")
                    .font(OwlFont.bottomBarButton)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button(action: onQuit) {
                Label("Quit", systemImage: "power")
                    .font(OwlFont.bottomBarButton)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, OwlLayout.popoverPaddingH)
        .padding(.vertical, 8)
    }
}
