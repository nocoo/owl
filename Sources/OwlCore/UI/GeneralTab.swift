import AppKit
import SwiftUI

/// General settings tab: logo header with version info, startup options,
/// language, appearance, monitoring config, and links.
public struct GeneralTab: View {
    @Binding var launchAtLogin: Bool
    @Binding var language: AppLanguage
    @Binding var appearance: AppAppearance
    let logoImage: NSImage?
    let version: String

    public init(
        launchAtLogin: Binding<Bool>,
        language: Binding<AppLanguage>,
        appearance: Binding<AppAppearance>,
        logoImage: NSImage? = nil,
        version: String = OwlInfo.version
    ) {
        self._launchAtLogin = launchAtLogin
        self._language = language
        self._appearance = appearance
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

                Text(L10n.tr(.appName))
                    .font(.system(size: 20, weight: .black))
                    .tracking(1.2)

                Text(
                    "v\(version) · \(L10n.tr(.systemHealthMonitor))"
                )
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 20)

            // Settings sections
            Form {
                Section(L10n.tr(.sectionStartup)) {
                    Toggle(
                        L10n.tr(.launchAtLogin),
                        isOn: $launchAtLogin
                    )
                }

                Section(L10n.tr(.sectionLanguage)) {
                    Picker(
                        L10n.tr(.language),
                        selection: $language
                    ) {
                        ForEach(
                            AppLanguage.allCases, id: \.self
                        ) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                }

                Section(L10n.tr(.sectionAppearance)) {
                    Picker(
                        L10n.tr(.appearanceMode),
                        selection: $appearance
                    ) {
                        ForEach(
                            AppAppearance.allCases, id: \.self
                        ) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                Section(L10n.tr(.sectionMonitoring)) {
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
                }
            }
            .formStyle(.grouped)
            .font(.system(size: 14))

            Spacer()

            // Links
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
