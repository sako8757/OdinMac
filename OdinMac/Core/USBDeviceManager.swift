import Foundation
import Combine

/// Watches for a Samsung device in Download Mode by polling `heimdall detect`
/// (~10ms, non-destructive). Polling pauses automatically while Heimdall is
/// busy flashing so the two never contend for the same USB device.
final class USBDeviceManager: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var deviceInfo: DeviceInfo?

    private let heimdall: HeimdallManager
    private var timer: Timer?
    private var inFlight = false
    private var onConnected: ((Bool) -> Void)?

    init(heimdall: HeimdallManager) {
        self.heimdall = heimdall
    }

    func startMonitoring(onConnected: @escaping (Bool) -> Void) {
        self.onConnected = onConnected
        // Fire immediately, then poll.
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
        // Don't stack detects, and never poke the device mid-flash.
        guard !inFlight, !heimdall.isBusy else { return }
        inFlight = true
        heimdall.queue.async { [weak self] in
            guard let self else { return }
            let present = self.heimdall.detectOnQueue()
            DispatchQueue.main.async {
                self.inFlight = false
                guard present != self.isConnected else { return }
                self.isConnected = present
                self.deviceInfo = present ? DeviceInfo(productName: "Samsung (Download Mode)",
                                                       platform: "Odin / Download Mode") : nil
                self.onConnected?(present)
            }
        }
    }
}
