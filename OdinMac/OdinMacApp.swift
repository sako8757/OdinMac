import SwiftUI
import AppKit

enum WindowMetrics {
    static let size = NSSize(width: 1296, height: 888)
}

// Configures every NSWindow so our VStack content fills the full frame,
// with the OS traffic-light buttons sitting inside our 36pt custom titleBar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        configureWindows()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        configureWindows()
    }

    private func configureWindows() {
        for window in NSApplication.shared.windows {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.styleMask.remove(.resizable)
            window.collectionBehavior.remove(.fullScreenPrimary)
            window.contentMinSize = WindowMetrics.size
            window.contentMaxSize = WindowMetrics.size
            window.setContentSize(WindowMetrics.size)
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            window.isMovableByWindowBackground = false
        }
    }
}

@main
struct OdinMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var flashVM = FlashViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(flashVM)
                .frame(width: WindowMetrics.size.width, height: WindowMetrics.size.height)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
