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
        List {
            // About section with logo, version, and GitHub link
            Section {
                HStack(spacing: 12) {
                    if let logoImage {
                        Image(nsImage: logoImage)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 11)
                            )
                            .shadow(radius: 2, y: 1)
                    } else {
                        Image(systemName: "bird.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                            .frame(width: 48, height: 48)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr(.appName))
                            .font(.system(size: 14, weight: .bold))
                        HStack(spacing: 4) {
                            Text(
                                "v\(version) · \(L10n.tr(.systemHealthMonitor))"
                            )
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            if let url = URL(
                                string:
                                    "https://github.com/nocoo/owl"
                            ) {
                                Text("·")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                                Link("GitHub", destination: url)
                                    .font(.system(size: 12))
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label(L10n.tr(.sectionAbout), systemImage: "info.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            // Startup section
            Section {
                Toggle(
                    L10n.tr(.launchAtLogin),
                    isOn: $launchAtLogin
                )
            } header: {
                Label(L10n.tr(.sectionStartup), systemImage: "power")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            // Monitoring section
            Section {
                HStack {
                    Text(L10n.tr(.refreshInterval))
                    Spacer()
                    Text(L10n.tr(.refreshIntervalValue))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(L10n.tr(.logBufferSize))
                    Spacer()
                    Text(L10n.tr(.logBufferSizeValue))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label(L10n.tr(.sectionMonitoring), systemImage: "gauge.high")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .font(.system(size: 14))
    }
}
