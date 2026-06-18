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
    var isHomebrew: Bool = false
}

struct SetupPermission {
    let id: String
    let icon: String
    let name: String
    let description: String
    var isAvailable: Bool
    var fixLabel: String? = nil
}

struct SetupView: View {
    @Binding var isPresented: Bool
    let heimdallAvailable: Bool
    var onDismiss: (() -> Void)? = nil

    @State private var tools: [SetupTool] = []
    @State private var permissions: [SetupPermission] = []
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
                    sectionLabel("Tools")
                    ForEach(tools.indices, id: \.self) { i in
                        toolRow(index: i)
                    }
                    if !installLog.isEmpty {
                        logView
                    }

                    sectionLabel("Permissions")
                        .padding(.top, 6)
                    ForEach(permissions.indices, id: \.self) { i in
                        permissionRow(index: i)
                    }
                }
                .padding(20)
            }
            Divider().opacity(0.15)
            footer
        }
        .frame(width: 540, height: 560)
        .background(Color(red: 0.06, green: 0.07, blue: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            checkTools()
            checkPermissions()
        }
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
            Text("OdinMac checks for required tools and permissions on launch.\nFix any issues below with one click.")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.06, green: 0.07, blue: 0.11))
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: 0) {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray.opacity(0.45))
            Spacer()
        }
        .padding(.horizontal, 2)
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
            } else if tool.isHomebrew {
                installButton(isBusy: installing == tool.id) {
                    installHomebrew(toolIndex: i)
                }
            } else if let pkg = tool.brewPackage, brewPath != nil {
                installButton(isBusy: installing == tool.id) {
                    install(package: pkg, toolIndex: i)
                }
            } else if tool.brewPackage != nil {
                Text("Needs Homebrew")
                    .font(.system(size: 11))
                    .foregroundColor(.orange.opacity(0.7))
            } else {
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

    private func installButton(isBusy: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isBusy {
                    ProgressView().scaleEffect(0.55).frame(width: 12, height: 12)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                }
                Text(isBusy ? "Installing…" : "Install")
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
    }

    // MARK: - Permission row

    private func permissionRow(index i: Int) -> some View {
        let perm = permissions[i]
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(perm.isAvailable
                          ? Color.green.opacity(0.18)
                          : Color.orange.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: perm.isAvailable ? "checkmark" : perm.icon)
                    .font(.system(size: 14, weight: perm.isAvailable ? .bold : .regular))
                    .foregroundColor(perm.isAvailable ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(perm.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(perm.description)
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))
                    .lineLimit(2)
            }

            Spacer()

            if perm.isAvailable {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green.opacity(0.8))
                    .labelStyle(.titleAndIcon)
            } else if let fixLabel = perm.fixLabel {
                Button {
                    fixPermission(id: perm.id)
                } label: {
                    HStack(spacing: 5) {
                        if installing == perm.id {
                            ProgressView().scaleEffect(0.55).frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "wrench.fill").font(.system(size: 11))
                        }
                        Text(installing == perm.id ? "Fixing…" : fixLabel)
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
            } else {
                Text("Limited")
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

    // MARK: - Checks

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
                id: "homebrew",
                icon: "shippingbox.fill",
                name: "Homebrew",
                description: "Package manager used to install lz4 and ADB below. Needs an admin password once.",
                isRequired: false,
                brewPackage: nil,
                isAvailable: brewPath != nil,
                isHomebrew: true
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

    private func checkPermissions() {
        let appPath = Bundle.main.bundleURL.path

        let quarantineProc = Process()
        quarantineProc.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        quarantineProc.arguments = ["-p", "com.apple.quarantine", appPath]
        quarantineProc.standardOutput = Pipe()
        quarantineProc.standardError = Pipe()
        var isQuarantined = false
        if (try? quarantineProc.run()) != nil {
            quarantineProc.waitUntilExit()
            isQuarantined = quarantineProc.terminationStatus == 0
        }

        let idProc = Process()
        idProc.executableURL = URL(fileURLWithPath: "/usr/bin/id")
        idProc.arguments = ["-Gn"]
        let idPipe = Pipe()
        idProc.standardOutput = idPipe
        idProc.standardError = Pipe()
        var isAdmin = false
        if (try? idProc.run()) != nil {
            idProc.waitUntilExit()
            let data = idPipe.fileHandleForReading.readDataToEndOfFile()
            let groups = String(data: data, encoding: .utf8) ?? ""
            isAdmin = groups.split(separator: " ").contains("admin")
        }

        // On macOS 15 (Sequoia) and later, USB accessories must be explicitly approved.
        // When macOS shows "Allow Accessory to Connect?" — click Allow.
        // If the prompt was missed or dismissed, the device won't appear on the USB bus at all.
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let needsUSBApproval = os.majorVersion >= 15

        var perms: [SetupPermission] = [
            SetupPermission(
                id: "gatekeeper",
                icon: "checkmark.shield.fill",
                name: "App Security (Gatekeeper)",
                description: "OdinMac isn't quarantined, so macOS won't re-block it on future launches.",
                isAvailable: !isQuarantined,
                fixLabel: isQuarantined ? "Remove Quarantine" : nil
            ),
            SetupPermission(
                id: "admin",
                icon: "person.badge.key.fill",
                name: "Admin Account",
                description: isAdmin
                    ? "Your account can authorize installing Homebrew and other tools."
                    : "Standard account. Installing Homebrew needs an administrator to enter their password.",
                isAvailable: isAdmin
            ),
        ]

        if needsUSBApproval {
            perms.append(SetupPermission(
                id: "usb_accessory",
                icon: "cable.connector",
                name: "USB Accessories",
                description: "macOS 15+ requires you to click \u{201C}Allow\u{201D} when connecting the phone. If you missed the prompt, open Privacy & Security \u{2192} USB Accessories.",
                isAvailable: false,
                fixLabel: "Open Settings"
            ))
        }

        permissions = perms
    }

    // MARK: - Fixes

    private func fixPermission(id: String) {
        if id == "usb_accessory" {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                NSWorkspace.shared.open(url)
            } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        guard id == "gatekeeper" else { return }
        installing = id
        let path = Bundle.main.bundleURL.path

        Task {
            let direct = Process()
            direct.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            direct.arguments = ["-dr", "com.apple.quarantine", path]
            direct.standardOutput = Pipe()
            direct.standardError = Pipe()
            try? direct.run()
            direct.waitUntilExit()

            if direct.terminationStatus != 0 {
                let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
                let script = "do shell script \"xattr -dr com.apple.quarantine \\\"\(escapedPath)\\\"\" with administrator privileges with prompt \"OdinMac needs to clear its quarantine flag.\""
                let elevated = Process()
                elevated.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                elevated.arguments = ["-e", script]
                elevated.standardOutput = Pipe()
                elevated.standardError = Pipe()
                try? elevated.run()
                elevated.waitUntilExit()
            }

            await MainActor.run {
                checkPermissions()
                installing = nil
            }
        }
    }

    private func install(package: String, toolIndex: Int) {
        guard let brew = brewPath else { return }
        let toolID = tools[toolIndex].id
        installing = toolID
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

    /// Homebrew's installer refuses to run as root and aborts if invoked from a
    /// `with administrator privileges` AppleScript block (which runs as root). So we
    /// only elevate the one step that genuinely needs it (creating /opt/homebrew and
    /// handing it to the current user), then run the official installer unprivileged.
    private func installHomebrew(toolIndex: Int) {
        let toolID = tools[toolIndex].id
        installing = toolID
        installLog = "$ Preparing /opt/homebrew (enter your password when prompted)...\n"

        Task {
            let user = NSUserName()
            let prepScript = "do shell script \"mkdir -p /opt/homebrew && chown -R \(user):admin /opt/homebrew\" with administrator privileges with prompt \"OdinMac needs to prepare /opt/homebrew before installing Homebrew.\""

            let prep = Process()
            prep.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            prep.arguments = ["-e", prepScript]
            let prepPipe = Pipe()
            prep.standardOutput = prepPipe
            prep.standardError = prepPipe

            do {
                try prep.run()
                prep.waitUntilExit()
                guard prep.terminationStatus == 0 else {
                    let data = prepPipe.fileHandleForReading.readDataToEndOfFile()
                    let msg = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    await MainActor.run {
                        installLog += "\n✗ Admin authorization was cancelled or failed.\(msg.map { " (\($0))" } ?? "")"
                        installing = nil
                    }
                    return
                }

                await MainActor.run { installLog += "✓ /opt/homebrew ready.\n$ Installing Homebrew (this can take a few minutes)...\n" }

                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/bash")
                proc.arguments = ["-c", "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""]
                var env = ProcessInfo.processInfo.environment
                env["NONINTERACTIVE"] = "1"
                proc.environment = env
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = pipe
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
                let newBrewPath = ["/opt/homebrew/bin/brew"].first(where: { fm.isExecutableFile(atPath: $0) })

                await MainActor.run {
                    brewPath = newBrewPath
                    tools[toolIndex].isAvailable = newBrewPath != nil
                    installLog += newBrewPath != nil
                        ? "\n✓ Homebrew installed successfully!"
                        : "\n✗ Homebrew installation may have failed (exit \(proc.terminationStatus))."
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
