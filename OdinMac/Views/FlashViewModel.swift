import Foundation
import SwiftUI
import Combine

@MainActor
final class FlashViewModel: ObservableObject {
    @Published var config  = FlashConfiguration()
    @Published private(set) var deviceInfo: DeviceInfo?
    @Published private(set) var isDeviceConnected = false
    @Published private(set) var logs: [LogEntry] = []
    @Published private(set) var flashState: FlashState = .idle
    @Published private(set) var overallProgress: Double = 0

    let adb    = ADBManager()
    let magisk = MagiskManager()
    let heimdall = HeimdallManager()
    let flasher: FirmwareFlasher

    @Published private(set) var heimdallAvailable = true

    private let usb: USBDeviceManager
    private var cancellables = Set<AnyCancellable>()

    var isFlashing: Bool {
        switch flashState {
        case .idle, .success, .failed, .cancelled: return false
        default: return true
        }
    }
    var canFlash: Bool { isDeviceConnected && config.hasAnyFile && !isFlashing && heimdallAvailable }

    init() {
        flasher = FirmwareFlasher(heimdall: heimdall)
        usb = USBDeviceManager(heimdall: heimdall)
        heimdallAvailable = heimdall.isAvailable

        config.onLog = { [weak self] msg, level in
            Task { @MainActor in self?.appendLog(msg, level: level) }
        }

        flasher.onLog = { [weak self] msg, level in
            Task { @MainActor in self?.appendLog(msg, level: level) }
        }
        flasher.$state
            .receive(on: DispatchQueue.main)
            .assign(to: &$flashState)
        flasher.$overallProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$overallProgress)

        magisk.onLog = { [weak self] msg, level in
            Task { @MainActor in self?.appendLog(msg, level: level) }
        }
        magisk.onPatchedBootReady = { [weak self] url in
            Task { @MainActor in
                self?.config.setFile(url, for: "AP")
                self?.appendLog("Patched boot loaded into AP slot: \(url.lastPathComponent)", level: .success)
            }
        }

        appendLog("OdinMac ready. Connect a Samsung device in Download Mode.", level: .info)
        appendLog("Download Mode: Vol Down + Bixby + Power  (older: Vol Down + Home + Power).", level: .info)
        if heimdall.isAvailable {
            appendLog("Flash engine: Heimdall \(heimdall.version)", level: .success)
        } else {
            appendLog("Heimdall engine not found inside the app. Rebuild with build.sh.", level: .error)
        }

        usb.startMonitoring { [weak self] connected in
            Task { @MainActor in
                self?.isDeviceConnected = connected
                if connected {
                    self?.appendLog("Samsung device connected in Download Mode!", level: .success)
                } else {
                    self?.appendLog("Device disconnected.", level: .warning)
                    self?.deviceInfo = nil
                }
            }
        }
        usb.$deviceInfo
            .receive(on: DispatchQueue.main)
            .assign(to: &$deviceInfo)

        // Poll ADB app-wide so device details (model, bootloader status, …)
        // are available on every tab, not just the Root tab.
        adb.startPolling()
    }

    func startFlash() {
        guard canFlash else { return }
        appendLog("Starting flash process...", level: .info)
        flasher.startFlash(config: config)
    }

    func stopFlash() { flasher.cancel() }

    func reset() {
        config.reset()
        appendLog("Configuration reset.", level: .info)
    }

    func clearLogs() { logs.removeAll() }

    private func appendLog(_ message: String, level: LogLevel = .info) {
        logs.append(LogEntry(message, level: level))
        if logs.count > 500 { logs.removeFirst(logs.count - 500) }
    }
}
