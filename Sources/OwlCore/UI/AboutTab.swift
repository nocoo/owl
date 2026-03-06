import AppKit
import SwiftUI

/// About tab showing app logo, name, version, and credits.
public struct AboutTab: View {
    let version: String
    let appIcon: NSImage?

    public init(
        version: String = OwlInfo.version,
        appIcon: NSImage? = nil
    ) {
        self.version = version
        self.appIcon = appIcon
    }

    public var body: some View {
        VStack(spacing: 12) {
            Spacer()

            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 20)
                    )
                    .shadow(radius: 4, y: 2)
            } else {
                Image(systemName: "bird.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }

            Text("Owl")
                .font(.title2.bold())

            Text("v\(version)")
                .font(
                    .system(size: 13, design: .monospaced)
                )
                .foregroundStyle(.secondary)

            Text("System health monitor for macOS")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Spacer()

            // Links
            HStack(spacing: 16) {
                if let url = URL(
                    string: "https://github.com/nocoo/owl"
                ) {
                    Link("GitHub", destination: url)
                        .font(.system(size: 11))
                }
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
