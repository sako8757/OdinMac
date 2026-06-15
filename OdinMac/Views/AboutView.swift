import SwiftUI
import AppKit

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                heroSection
                glassSection { featuresSection }
                glassSection { creditsSection }
                Spacer(minLength: 12)
            }
            .padding(24)
        }
        .background(Color(red: 0.05, green: 0.06, blue: 0.09))
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Text("OdinMac")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                Text("v\(version)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Text("·")
                    .foregroundColor(.white.opacity(0.2))
                Text("Samsung Firmware Flasher for macOS")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Features", icon: "star.fill")
            VStack(alignment: .leading, spacing: 8) {
                featureRow("bolt.fill",           "Firmware Flash",     "Load BL / AP / CP / CSC archives and flash in one pass")
                featureRow("doc.text.magnifyingglass", "File Inspection", "Shows archive size and partition list on file selection")
                featureRow("tablecells",           "PIT Mapping",        "Prefers firmware PIT; avoids known Heimdall device-PIT failures")
                featureRow("shield.fill",          "Root / Magisk",      "Guided 5-step Magisk installation workflow with ADB integration")
                featureRow("iphone",               "Device Info",        "Model, Android version, CSC and bootloader status via ADB")
                featureRow("checkmark.seal.fill",  "Self-contained",     "Heimdall + libusb bundled inside the app. Nothing to install.")
            }
        }
    }

    private func featureRow(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                .frame(width: 18, alignment: .center)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
    }

    // MARK: - Credits

    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Credits", icon: "heart.fill")
            VStack(spacing: 8) {
                creditRow(
                    icon: "bolt.fill",
                    name: "Heimdall v1.4.2",
                    role: "Flash engine (MIT License)",
                    url: "https://github.com/Benjamin-Dobell/Heimdall",
                    linkLabel: "Benjamin Dobell, Glass Echidna"
                )
                creditRow(
                    icon: "cpu.fill",
                    name: "Claude Code",
                    role: "AI-assisted development with Claude by Anthropic",
                    url: "https://claude.ai/code",
                    linkLabel: "claude.ai/code"
                )
            }
            .padding(.top, 2)

            Divider().opacity(0.15)

            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.4))
                Text("OdinMac is open source (MIT License)")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.5))
                Spacer()
            }
        }
    }

    private func creditRow(icon: String, name: String, role: String, url: String, linkLabel: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.8))
                .frame(width: 22, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                HStack(spacing: 4) {
                    Text(role)
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            Spacer()
            Link(linkLabel, destination: URL(string: url)!)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.7))
                .lineLimit(1)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1))
        )
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.8))
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))
            Spacer()
        }
    }

    private func glassSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
