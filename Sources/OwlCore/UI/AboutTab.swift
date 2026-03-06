import SwiftUI

/// About tab showing app name, version, and icon.
public struct AboutTab: View {
    let version: String

    public init(version: String = OwlInfo.version) {
        self.version = version
    }

    public var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "owl.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Owl")
                .font(.title2.bold())

            Text("v\(version)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("System health monitor for macOS")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
