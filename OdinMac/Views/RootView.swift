import SwiftUI

struct RootView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {

                // Icon badge
                ZStack {
                    Circle()
                        .fill(Color(red: 0.10, green: 0.14, blue: 0.24))
                        .frame(width: 80, height: 80)
                    Circle()
                        .stroke(Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.18), lineWidth: 1.5)
                        .frame(width: 80, height: 80)
                    Image(systemName: "shield.lefthalf.filled.slash")
                        .font(.system(size: 34, weight: .light))
                        .foregroundColor(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.6))
                }

                // Heading
                VStack(spacing: 10) {
                    Text("Root / Magisk")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))

                    Text("Coming in a future release")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(red: 0.3, green: 0.65, blue: 1.0).opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.10, green: 0.18, blue: 0.35))
                                .overlay(
                                    Capsule()
                                        .stroke(Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.2), lineWidth: 1)
                                )
                        )
                }

                // Planned features
                VStack(alignment: .leading, spacing: 10) {
                    plannedFeature(icon: "wand.and.stars",     text: "Guided Magisk installation workflow")
                    plannedFeature(icon: "desktopcomputer",    text: "Patch boot image directly on Mac")
                    plannedFeature(icon: "iphone.and.arrow.forward.inward", text: "ADB integration for device control")
                    plannedFeature(icon: "bolt.fill",          text: "Flash patched boot in one click")
                }

                // Hint
                Text("Use the Flash tab to load and flash Samsung firmware while this feature is being developed.")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .padding(40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.055, green: 0.065, blue: 0.095))
    }

    private func plannedFeature(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.5))
                .frame(width: 18, alignment: .center)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.5))
        }
    }
}
