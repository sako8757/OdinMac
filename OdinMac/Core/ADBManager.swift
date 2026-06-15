import Foundation
import Combine

enum ADBError: LocalizedError {
    case notFound
    case noDevice
    case multipleDevices
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:           return "adb not found. Install Android Platform Tools."
        case .noDevice:           return "No Android device connected via USB"
        case .multipleDevices:    return "Multiple devices connected. Connect only one."
        case .commandFailed(let m): return m
        }
    }
}

struct ADBDevice {
    let serial: String
    let state: String   // "device", "recovery", "unauthorized", etc.
    var model: String = ""
}

/// Device details read from `getprop` while the phone is booted normally.
struct DeviceDetails: Equatable {
    var model: String = "N/A"          // ro.product.model  e.g. SM-G991B
    var codename: String = "N/A"       // ro.product.device e.g. o1s
    var androidVersion: String = "N/A" // ro.build.version.release
    var bootloader: String = "N/A"     // ro.bootloader
    var salesCode: String = "N/A"      // CSC / region
    var bootloaderUnlocked: Bool?    // nil = unknown
    var verifiedBootState: String = "N/A"  // green / orange / yellow
    var warrantyVoid: Bool?
    var oemUnlockAllowed: Bool?

    var bootloaderText: String {
        switch bootloaderUnlocked {
        case .some(true):  return "UNLOCKED"
        case .some(false): return "LOCKED"
        case .none:        return "Unknown"
        }
    }
}

@MainActor
final class ADBManager: ObservableObject {
    @Published private(set) var device: ADBDevice?
    @Published private(set) var details: DeviceDetails?
    @Published private(set) var isConnected = false
    @Published private(set) var adbAvailable = false

    private var adbPath = "adb"
    private var pollTask: Task<Void, Never>?

    init() {
        Task { await discoverADB() }
    }

    deinit {
        pollTask?.cancel()
    }

    // MARK: - Discovery

    private func discoverADB() async {
        let candidates = [
            "/opt/homebrew/bin/adb",
            "/usr/local/bin/adb",
            "\(NSHomeDirectory())/Library/Android/sdk/platform-tools/adb",
            "\(NSHomeDirectory())/platform-tools/adb",
            "/usr/bin/adb",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                adbPath = path
                adbAvailable = true
                return
            }
        }
        // Fall back to PATH
        let result = await shell(["which", "adb"])
        let trimmed = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !trimmed.contains("not found") {
            adbPath = trimmed
            adbAvailable = true
        }
    }

    // MARK: - Device polling

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await refreshDevices()
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            }
        }
    }

    func stopPolling() { pollTask?.cancel() }

    func refreshDevices() async {
        let result = await adb(["devices", "-l"])
        let lines = result.out.components(separatedBy: "\n")
            .filter { !$0.hasPrefix("List of devices") && !$0.isEmpty }

        let devices: [ADBDevice] = lines.compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count >= 2 else { return nil }
            let serial = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let state  = String(parts[1]).components(separatedBy: " ").first ?? ""
            return ADBDevice(serial: serial, state: state)
        }

        if var dev = devices.first(where: { $0.state == "device" }) {
            let det = await fetchDetails(serial: dev.serial)
            dev.model = det.model
            device = dev
            details = det
            isConnected = true
        } else {
            device = nil
            details = nil
            isConnected = false
        }
    }

    /// Reads the device property table once and extracts the fields we show,
    /// including bootloader lock status.
    private func fetchDetails(serial: String) async -> DeviceDetails {
        let dump = await adb(["-s", serial, "shell", "getprop"])
        var props: [String: String] = [:]
        for line in dump.out.components(separatedBy: "\n") {
            // format: [key]: [value]
            guard let lb = line.range(of: "]: ["), line.hasPrefix("[") , line.hasSuffix("]") else { continue }
            let key = String(line[line.index(after: line.startIndex)..<lb.lowerBound])
            let value = String(line[lb.upperBound..<line.index(before: line.endIndex)])
            props[key] = value
        }
        func first(_ keys: [String]) -> String {
            for k in keys { if let v = props[k], !v.isEmpty { return v } }
            return "N/A"
        }

        var d = DeviceDetails()
        d.model          = first(["ro.product.model", "ro.product.vendor.model"])
        d.codename       = first(["ro.product.device", "ro.product.vendor.device"])
        d.androidVersion = first(["ro.build.version.release"])
        d.bootloader     = first(["ro.bootloader", "ro.boot.bootloader"])
        d.salesCode      = first(["ro.csc.sales_code", "ro.boot.sales_code", "ril.sales_code"])
        d.verifiedBootState = first(["ro.boot.verifiedbootstate"])

        let flashLocked = props["ro.boot.flash.locked"]
        if flashLocked == "1" { d.bootloaderUnlocked = false }
        else if flashLocked == "0" { d.bootloaderUnlocked = true }
        else if d.verifiedBootState == "green" { d.bootloaderUnlocked = false }
        else if d.verifiedBootState == "orange" || d.verifiedBootState == "yellow" { d.bootloaderUnlocked = true }

        if let w = props["ro.boot.warranty_bit"] ?? props["ro.warranty_bit"] { d.warrantyVoid = (w == "1") }
        if let o = props["sys.oem_unlock_allowed"] { d.oemUnlockAllowed = (o == "1") }
        return d
    }

    // MARK: - High-level operations

    func installMagisk(apkURL: URL) async throws -> String {
        guard let serial = device?.serial else { throw ADBError.noDevice }
        let result = await adb(["-s", serial, "install", "-r", apkURL.path])
        guard result.code == 0 else { throw ADBError.commandFailed(result.out) }
        return "Magisk APK installed"
    }

    /// List magisk_patched*.tar files on the device SD card
    func findMagiskPatched() async throws -> [String] {
        guard let serial = device?.serial else { throw ADBError.noDevice }
        let result = await adb(["-s", serial, "shell",
            "find /sdcard/Download /sdcard -maxdepth 3 -name 'magisk_patched*.tar' 2>/dev/null"])
        guard result.code == 0 else { throw ADBError.commandFailed(result.out) }
        return result.out
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Pull a file from device to a local temp URL
    func pullFile(from remotePath: String, progressHandler: ((Double) -> Void)? = nil) async throws -> URL {
        guard let serial = device?.serial else { throw ADBError.noDevice }
        let fileName  = (remotePath as NSString).lastPathComponent
        let destURL   = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: destURL)

        let result = await adb(["-s", serial, "pull", remotePath, destURL.path])
        guard result.code == 0, FileManager.default.fileExists(atPath: destURL.path) else {
            throw ADBError.commandFailed(result.out)
        }
        return destURL
    }

    /// Push a file to the device
    func pushFile(from localURL: URL, to remotePath: String) async throws {
        guard let serial = device?.serial else { throw ADBError.noDevice }
        let result = await adb(["-s", serial, "push", localURL.path, remotePath])
        guard result.code == 0 else { throw ADBError.commandFailed(result.out) }
    }

    /// Reboot device into download mode
    func rebootDownload() async throws {
        guard let serial = device?.serial else { throw ADBError.noDevice }
        await adb(["-s", serial, "reboot", "download"])
    }

    /// Reboot device into recovery
    func rebootRecovery() async throws {
        guard let serial = device?.serial else { throw ADBError.noDevice }
        await adb(["-s", serial, "reboot", "recovery"])
    }

    // MARK: - Internal runners

    @discardableResult
    func adb(_ args: [String]) async -> (out: String, code: Int32) {
        return await shell([adbPath] + args)
    }

    private func shell(_ cmd: [String]) async -> (out: String, code: Int32) {
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: cmd[0])
                proc.arguments = Array(cmd.dropFirst())
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError  = pipe
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let str  = String(data: data, encoding: .utf8) ?? ""
                    cont.resume(returning: (str, proc.terminationStatus))
                } catch {
                    cont.resume(returning: ("Error: \(error.localizedDescription)", -1))
                }
            }
        }
    }
}
