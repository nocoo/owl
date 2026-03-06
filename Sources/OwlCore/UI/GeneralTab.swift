import SwiftUI

/// General settings tab: launch at login toggle.
public struct GeneralTab: View {
    @Binding var launchAtLogin: Bool

    public init(launchAtLogin: Binding<Bool>) {
        self._launchAtLogin = launchAtLogin
    }

    public var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
        }
        .padding()
    }
}
