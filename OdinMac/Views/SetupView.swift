import SwiftUI
import AppKit

struct SetupTool {
    let id: String
    let icon: String
    let name: String
    let description: String
    let isRequired: Bool
    let brewPackage: String?
    var isAvailable: Bool
}

struct SetupView: View {
    @Binding var isPresented: Bool
    let heimdallAvailable: Bool
    var onDismiss: (() -> Void)? = nil

    @State private var tools: [SetupTool] = []
    @State private var installing: String? = nil
    @State private var installLog = ""
    @State private var brewPath: String? = nil

    private var allRequiredAvailable: Bool {
        tools.filter { $0.isRequired }.allSatisfy { $0.isAvailable }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.15)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(tools.indices, id: \.self) { i in
                        toolRow(index: i)
                    }
                    if !installLog.isEmpty {
                        logView
                    }
                    if brewPath == nil {
                        brewMissingNote
                    }
                }
                .padding(20)
            }
            Divider().opacity(0.15)
            footer
        }
        .frame(width: 540, height: 460)
        .background(Color(red: 0.06, green: 0.07, blue: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear(perform: checkTools)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                Text("Setup & Requirements")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("OdinMac checks for required tools on launch.\nInstall any missing items below with one click via Homebrew.")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.06, green: 0.07, blue: 0.11))
    }

    // MARK: - Tool row

    private func toolRow(index i: Int) -> some View {
        let tool = tools[i]
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tool.isAvailable
                          ? Color.green.opacity(0.18)
                          : Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: tool.isAvailable ? "checkmark" : tool.icon)
                    .font(.system(size: 14, weight: tool.isAvailable ? .bold : .regular))
                    .foregroundColor(tool.isAvailable ? .green : Color(red: 0.2, green: 0.6, blue: 1.0))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(tool.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    if tool.isRequired {
                        Text("REQUIRED")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.14)))
                    } else {
                        Text("optional")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.45))
                    }
                }
                Text(tool.description)
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))
                    .lineLimit(2)
            }

            Spacer()

            if tool.isAvailable {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green.opacity(0.8))
                    .labelStyle(.titleAndIcon)
            } else if let pkg = tool.brewPackage, brewPath != nil {
                Button {
                    install(package: pkg, toolIndex: i)
                } label: {
                    HStack(spacing: 5) {
                        if installing == pkg {
                            ProgressView().scaleEffect(0.55).frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 12))
                        }
                        Text(installing == pkg ? "Installing…" : "Install")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 7)
                                .stroke(Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.4), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .disabled(installing != nil)
            } else if !tool.isAvailable {
                Text("Not found")
                    .font(.system(size: 11))
                    .foregroundColor(.orange.opacity(0.7))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.10, green: 0.11, blue: 0.17))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Install log

    private var logView: some View {
        ScrollView {
            Text(installLog)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.green.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(maxHeight: 90)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Brew missing note

    private var brewMissingNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundColor(.orange.opacity(0.8))
            VStack(alignment: .leading, spacing: 2) {
                Text("Homebrew not found")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                Text("Install Homebrew to enable one-click tool installation: brew.sh")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))
            }
            Spacer()
            Link("brew.sh", destination: URL(string: "https://brew.sh")!)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.orange.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.orange.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            if allRequiredAvailable {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                Text("All required tools are ready.")
                    .font(.system(size: 12))
                    .foregroundColor(.green.opacity(0.8))
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                Text("Some required tools are missing.")
                    .font(.system(size: 12))
                    .foregroundColor(.orange.opacity(0.8))
            }
            Spacer()
            Button("Continue") {
                onDismiss?()
                isPresented = false
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 22).padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.2, green: 0.6, blue: 1.0).opacity(allRequiredAvailable ? 1.0 : 0.4))
            )
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(Color(red: 0.05, green: 0.06, blue: 0.09))
    }

    // MARK: - Logic

    private func checkTools() {
        let fm = FileManager.default
        brewPath = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first(where: { fm.isExecutableFile(atPath: $0) })

        let lz4OK = ["/opt/homebrew/bin/lz4", "/usr/local/bin/lz4", "/usr/bin/lz4"]
            .contains(where: { fm.isExecutableFile(atPath: $0) })
        let adbOK = ["/opt/homebrew/bin/adb", "/usr/local/bin/adb", "/usr/bin/adb"]
            .contains(where: { fm.isExecutableFile(atPath: $0) })

        tools = [
            SetupTool(
                id: "heimdall",
                icon: "bolt.fill",
                name: "Heimdall",
                description: "Core Samsung flash engine, bundled inside OdinMac.app. No installation needed.",
                isRequired: true,
                brewPackage: nil,
                isAvailable: heimdallAvailable
            ),
            SetupTool(
                id: "lz4",
                icon: "doc.zipper",
                name: "lz4",
                description: "Decompresses .lz4-compressed firmware images. Required for most modern Samsung firmware packages.",
                isRequired: false,
                brewPackage: "lz4",
                isAvailable: lz4OK
            ),
            SetupTool(
                id: "adb",
                icon: "iphone",
                name: "ADB (Android Debug Bridge)",
                description: "Enables ADB device management: pulling patched boot images and rebooting to Download Mode.",
                isRequired: false,
                brewPackage: "android-platform-tools",
                isAvailable: adbOK
            ),
        ]
    }

    private func install(package: String, toolIndex: Int) {
        guard let brew = brewPath else { return }
        installing = package
        installLog = "$ brew install \(package)\n"

        Task {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: brew)
            proc.arguments = ["install", package]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            do {
                try proc.run()
                let handle = pipe.fileHandleForReading
                while true {
                    let data = handle.availableData
                    if data.isEmpty { break }
                    if let str = String(data: data, encoding: .utf8) {
                        await MainActor.run { installLog += str }
                    }
                }
                proc.waitUntilExit()

                let fm = FileManager.default
                let isNow: Bool
                switch package {
                case "lz4":
                    isNow = ["/opt/homebrew/bin/lz4", "/usr/local/bin/lz4"]
                        .contains(where: { fm.isExecutableFile(atPath: $0) })
                case "android-platform-tools":
                    isNow = ["/opt/homebrew/bin/adb", "/usr/local/bin/adb"]
                        .contains(where: { fm.isExecutableFile(atPath: $0) })
                default:
                    isNow = proc.terminationStatus == 0
                }

                await MainActor.run {
                    tools[toolIndex].isAvailable = isNow
                    installLog += isNow
                        ? "\n✓ \(package) installed successfully!"
                        : "\n✗ Installation may have failed (exit \(proc.terminationStatus))."
                    installing = nil
                }
            } catch {
                await MainActor.run {
                    installLog += "Error: \(error.localizedDescription)"
                    installing = nil
                }
            }
        }
    }
}
