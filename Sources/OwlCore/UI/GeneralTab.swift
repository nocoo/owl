import SwiftUI

/// General settings tab with app header and startup options.
public struct GeneralTab: View {
    @Binding var launchAtLogin: Bool

    public init(launchAtLogin: Binding<Bool>) {
        self._launchAtLogin = launchAtLogin
    }

    public var body: some View {
        VStack(spacing: 0) {
            // App header
            VStack(spacing: 6) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Owl")
                    .font(.system(size: 18, weight: .bold))
                Text("System Health Monitor")
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
        }
    }
}
