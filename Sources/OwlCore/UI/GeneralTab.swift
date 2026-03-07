import AppKit
import SwiftUI

/// General settings tab: logo header with version info, startup options,
/// monitoring config, and links (merged from former About tab).
public struct GeneralTab: View {
    @Binding var launchAtLogin: Bool
    let logoImage: NSImage?
    let version: String

    public init(
        launchAtLogin: Binding<Bool>,
        logoImage: NSImage? = nil,
        version: String = OwlInfo.version
    ) {
        self._launchAtLogin = launchAtLogin
        self.logoImage = logoImage
        self.version = version
    }

    public var body: some View {
        VStack(spacing: 0) {
            // App header with logo
            VStack(spacing: 6) {
                if let logoImage {
                    Image(nsImage: logoImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 26)
                        )
                        .shadow(radius: 4, y: 2)
                } else {
                    Image(systemName: "bird.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }

                Text("Owl")
                    .font(.system(size: 16, weight: .bold))

                Text("v\(version) · System Health Monitor")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 20)

            // Settings sections
            Form {
                Section("Startup") {
                    Toggle(
                        "Launch at Login",
                        isOn: $launchAtLogin
                    )
                }

                Section("Monitoring") {
                    HStack {
                        Text("Refresh Interval")
                        Spacer()
                        Text("1 second")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Log Buffer Size")
                        Spacer()
                        Text("256 entries")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .font(.system(size: 14))

            Spacer()

            // Links (from former About tab)
            HStack(spacing: 16) {
                if let url = URL(
                    string: "https://github.com/nocoo/owl"
                ) {
                    Link("GitHub", destination: url)
                        .font(.system(size: 12))
                }
            }
            .padding(.bottom, 12)
        }
    }
}
