import Foundation
import Combine
import IOKit

/// Watches for a Samsung device in Download Mode using a two-stage approach:
///
///  1. IOKit direct check — queries the USB bus for any Samsung VID (0x04E8) device
///     without claiming any interface (~1 ms, never fails due to USB state issues).
///  2. Heimdall confirm — only runs `heimdall detect` if stage 1 found something,
///     to verify the device is actually responding to the Odin Download Mode handshake.
///
/// This avoids the previous single-subprocess approach which could silently fail on
/// macOS 15+ when the USB accessory hadn't been explicitly approved in System Settings,
/// or when the device's USB interface was stuck from a prior failed session.
final class USBDeviceManager: ObservableObject {

    /// Samsung Electronics USB vendor ID.
    static let samsungVID = 0x04E8

    @Published private(set) var isConnected = false
    @Published private(set) var deviceInfo: DeviceInfo?
    /// True when a Samsung device (any mode) is visible on the USB bus via IOKit,
    /// even if it hasn't entered Download Mode yet. Lets the UI give a better hint.
    @Published private(set) var usbBusPresent = false

    private let heimdall: HeimdallManager
    private var timer: Timer?
    private var inFlight = false
    private var onConnected: ((Bool) -> Void)?

    init(heimdall: HeimdallManager) {
        self.heimdall = heimdall
    }

    func startMonitoring(onConnected: @escaping (Bool) -> Void) {
        self.onConnected = onConnected
        poll()
        let t = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        t.tolerance = 0.5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard !inFlight, !heimdall.isBusy else { return }
        inFlight = true
        heimdall.queue.async { [weak self] in
            guard let self else { return }

            // Stage 1 — IOKit: is any Samsung device visible on the USB bus at all?
            // This never claims an interface so it always works regardless of USB state.
            let onBus = Self.isSamsungOnUSBBus()

            // Stage 2 — heimdall detect: only run if stage 1 found something.
            // This confirms the device is in Download Mode and responding.
            let inDL = onBus && self.heimdall.detectOnQueue()

            DispatchQueue.main.async {
                self.inFlight = false
                self.usbBusPresent = onBus
                guard inDL != self.isConnected else { return }
                self.isConnected = inDL
                self.deviceInfo = inDL ? DeviceInfo(productName: "Samsung (Download Mode)",
                                                    platform: "Odin / Download Mode") : nil
                self.onConnected?(inDL)
            }
        }
    }

    /// Returns true if any Samsung device (VID 0x04E8) appears in the IOKit USB registry.
    /// Does NOT open or claim any interface — safe to call at any time, even mid-flash.
    /// Tries IOUSBHostDevice (macOS 12+) first, then falls back to IOUSBDevice.
    static func isSamsungOnUSBBus() -> Bool {
        for className in ["IOUSBHostDevice", "IOUSBDevice"] {
            guard let base = IOServiceMatching(className) else { continue }
            let dict = base as NSMutableDictionary
            dict["idVendor"] = samsungVID
            var iter: io_iterator_t = 0
            guard IOServiceGetMatchingServices(0, dict as CFDictionary, &iter) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(iter) }
            if IOIteratorNext(iter) != 0 { return true }
        }
        return false
    }
}
