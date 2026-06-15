import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var vm: FlashViewModel
    @State private var selectedTab = 0
    @State private var showSetup = false
    @AppStorage("odinmac.setupDismissed") private var setupDismissed = false

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            if !vm.heimdallAvailable { engineMissingBanner }
            DeviceStatusView(
                isConnected: vm.isDeviceConnected,
                info: vm.deviceInfo,
                flashState: vm.flashState
            )
            if vm.adb.isConnected, let d = vm.adb.details {
                adbDeviceInfoBar(d)
            }
            Divider().background(Color.gray.opacity(0.2))
            tabBar
            tabContent
            Divider().background(Color.gray.opacity(0.2))
            progressBar
            Divider().background(Color.gray.opacity(0.2))
            actionButtons
            Divider().background(Color.gray.opacity(0.15))
            footerBar
        }
        .background(Color(red: 0.05, green: 0.06, blue: 0.09))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSetup) {
            SetupView(isPresented: $showSetup, heimdallAvailable: vm.heimdallAvailable) {
                setupDismissed = true
            }
        }
        .onAppear {
            if !setupDismissed {
                showSetup = true
            }
        }
    }

    // MARK: - Title bar
    // Note: real macOS traffic lights are rendered by the OS over this view.
    // We leave 72 pt of left padding so they don't overlap the title text.

    private var titleBar: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.13)
            // Centre the title; leave 76 pt on the left for the OS traffic lights.
            HStack(spacing: 0) {
                Spacer(minLength: 76)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                Text("  OdinMac")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                Text("  v\(appVersion)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.4))
                Spacer()
            }
            // Flash status chip (right-aligned in title bar)
            HStack {
                Spacer()
                titleBarStatus
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 40)
        .overlay(Divider().background(Color.white.opacity(0.08)), alignment: .bottom)
    }

    @ViewBuilder
    private var titleBarStatus: some View {
        switch vm.flashState {
        case .idle:
            EmptyView()
        default:
            HStack(spacing: 6) {
                if vm.isFlashing {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 12, height: 12)
                } else {
                    Circle()
                        .fill(progressColor)
                        .frame(width: 6, height: 6)
                }
                Text(progressLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(String(format: "%.0f%%", vm.overallProgress * 100))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.7))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(progressColor.opacity(0.4), lineWidth: 0.5))
        }
    }

    // MARK: - ADB device info (shown when the phone is booted normally)

    private func adbDeviceInfoBar(_ d: DeviceDetails) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            infoChip("Model", d.model)
            infoChip("Android", d.androidVersion)
            infoChip("CSC", d.salesCode)
            infoChip("Bootloader", d.bootloader)
            Spacer()
            if d.warrantyVoid == true {
                badge("KNOX VOID", .red)
            }
            bootloaderBadge(d)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(red: 0.09, green: 0.09, blue: 0.12))
        .overlay(Divider().opacity(0.15), alignment: .bottom)
    }

    private func infoChip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 130, alignment: .leading)
                .help(value)
        }
    }

    private func bootloaderBadge(_ d: DeviceDetails) -> some View {
        let color: Color = {
            switch d.bootloaderUnlocked {
            case .some(true):  return .orange
            case .some(false): return Color(red: 0.2, green: 0.8, blue: 0.4)
            case .none:        return .gray
            }
        }()
        return HStack(spacing: 4) {
            Image(systemName: d.bootloaderUnlocked == true ? "lock.open.fill"
                              : d.bootloaderUnlocked == false ? "lock.fill" : "questionmark")
                .font(.system(size: 8))
            Text("BOOTLOADER \(d.bootloaderText)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
        }
        .foregroundColor(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(color.opacity(0.4), lineWidth: 1))
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color.opacity(0.4), lineWidth: 1))
    }

    private var engineMissingBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 11))
            Text("Heimdall flash engine not found inside the app. Rebuild with build.sh.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.orange)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.12))
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton("Flash", icon: "bolt.fill",        index: 0)
                tabButton("PIT",   icon: "tablecells",       index: 1)
                tabButton("Root",  icon: "shield.fill",      index: 2, accent: .green)
                tabButton("About", icon: "info.circle.fill", index: 3)
            }
            Spacer()
            Button {
                showSetup = true
            } label: {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.45))
                    .padding(.horizontal, 11)
            }
            .buttonStyle(.plain)
            .help("Setup & Requirements")
        }
        .background(Color(red: 0.07, green: 0.08, blue: 0.12))
    }

    private func tabButton(_ title: String, icon: String, index: Int, accent: Color = .white) -> some View {
        let isActive = selectedTab == index
        return Button { selectedTab = index } label: {
            VStack(spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? accent : .gray.opacity(0.45))
                    Text(title)
                        .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? (accent == .white ? .white : accent) : .gray.opacity(0.55))
                }
                Capsule()
                    .fill(isActive ? accent : Color.clear)
                    .frame(width: 30, height: 1.5)
            }
            .padding(.horizontal, 10)
            .padding(.top, 5)
            .padding(.bottom, 4)
            .background(isActive
                ? Color(red: 0.12, green: 0.14, blue: 0.22).opacity(0.9)
                : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    PartitionPanelView(config: vm.config)
                    Divider().background(Color.white.opacity(0.06))
                    FlashOptionsView(config: vm.config)
                    Divider().background(Color.white.opacity(0.06))
                    LogView(entries: vm.logs)
                        .frame(minHeight: 135, idealHeight: 135, maxHeight: 135)
                        .clipped()
                    Spacer(minLength: 0)
                }
                .background(workspaceColor)

                Divider().background(Color.white.opacity(0.08))

                InfoPanelView(config: vm.config)
                    .frame(width: 310)
                    .frame(maxHeight: .infinity)
            }
            .background(workspaceColor)
        case 1: pitPanel.frame(maxHeight: .infinity)
        case 2: RootView().frame(maxHeight: .infinity)
        case 3: AboutView().frame(maxHeight: .infinity)
        default: EmptyView()
        }
    }

    // MARK: - PIT panel

    private var pitPanel: some View {
        Group {
            if let pit = vm.flasher.pitTable {
                pitTableView(pit)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "tablecells").font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                    Text("PIT table not yet loaded").font(.system(size: 12)).foregroundColor(.gray.opacity(0.5))
                    Text("Downloaded automatically at flash start.")
                        .font(.system(size: 10)).foregroundColor(.gray.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func pitTableView(_ pit: PITTable) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                pitHeaderRow
                ForEach(Array(pit.entries.enumerated()), id: \.offset) { _, e in pitEntryRow(e) }
            }
        }
        .padding(8)
    }

    private var pitHeaderRow: some View {
        HStack(spacing: 0) {
            pitCell("ID",    40, header: true);  pitCell("Name",       130, header: true)
            pitCell("Flash", 130, header: true); pitCell("Size",       80, header: true)
            pitCell("Type",  80, header: true);  Spacer()
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
    }

    private func pitEntryRow(_ e: PITEntry) -> some View {
        HStack(spacing: 0) {
            pitCell("\(e.identifier)", 40); pitCell(e.partitionName, 130)
            pitCell(e.flashFileName, 130); pitCell(String(format: "%.1f MB", e.sizeMB), 80)
            pitCell(deviceTypeLabel(e.deviceType), 80); Spacer()
        }
        .background(Color(red: 0.09, green: 0.09, blue: 0.12))
        .overlay(Divider().opacity(0.1), alignment: .bottom)
    }

    private func pitCell(_ text: String, _ width: CGFloat, header: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 10, weight: header ? .semibold : .regular, design: .monospaced))
            .foregroundColor(header ? .gray : .white.opacity(0.8))
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 6).padding(.vertical, 4)
    }

    private func deviceTypeLabel(_ t: UInt32) -> String {
        switch t { case 0: "OneNAND"; case 1: "File"; case 2: "MMC"; case 3: "All"; default: "Unknown" }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color(red: 0.08, green: 0.09, blue: 0.14)
                Rectangle()
                    .fill(progressColor)
                    .frame(width: geo.size.width * vm.overallProgress)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vm.overallProgress)
                HStack {
                    Text(progressLabel)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.leading, 10)
                    Spacer()
                    Text(String(format: "%.1f%%", vm.overallProgress * 100))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.trailing, 10)
                }
            }
        }
        .frame(height: 22)
    }

    private var progressColor: Color {
        switch vm.flashState {
        case .success:  Color(red: 0.1, green: 0.7, blue: 0.3)
        case .failed:   Color(red: 0.7, green: 0.1, blue: 0.1)
        case .cancelled:Color(red: 0.7, green: 0.4, blue: 0.1)
        default:        Color(red: 0.1, green: 0.4, blue: 0.9)
        }
    }

    private var progressLabel: String {
        switch vm.flashState {
        case .idle:                   return "Idle"
        case .connecting:             return "Connecting..."
        case .handshaking:            return "Handshaking..."
        case .gettingDeviceInfo:      return "Reading device info..."
        case .downloadingPIT:         return "Downloading PIT..."
        case .flashing(let n, _):     return "Flashing \(n)..."
        case .finishing:              return "Finishing..."
        case .success:                return "Flash complete!"
        case .failed(let e):          return "Error: \(e.localizedDescription)"
        case .cancelled:              return "Cancelled"
        }
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Spacer()
            actionBtn("Clear Log",  icon: "trash",                   color: .gray.opacity(0.7)) { vm.clearLogs() }
            actionBtn("Reset",      icon: "arrow.counterclockwise",  color: .gray)              { vm.reset() }
            actionBtn(
                vm.isFlashing ? "Stop Flash" : "Start Flash",
                icon:  vm.isFlashing ? "stop.fill" : "bolt.fill",
                color: vm.isFlashing ? .red : (vm.canFlash ? Color(red: 0.2, green: 0.6, blue: 1.0) : .gray),
                enabled: vm.isFlashing || vm.canFlash,
                primary: !vm.isFlashing && vm.canFlash
            ) {
                vm.isFlashing ? vm.stopFlash() : vm.startFlash()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.07, green: 0.07, blue: 0.11))
    }

    private func actionBtn(_ label: String, icon: String, color: Color,
                           enabled: Bool = true, primary: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(enabled ? (primary ? .white : color) : color.opacity(0.25))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(primary && enabled ? color : Color(red: 0.11, green: 0.12, blue: 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        enabled ? color.opacity(primary ? 0.0 : 0.35) : color.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain).disabled(!enabled)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.6))
                Text("OdinMac v\(appVersion)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                Text("·")
                    .foregroundColor(.gray.opacity(0.25))
                Text("Samsung Firmware Flasher for macOS")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.35))
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(Color(red: 0.05, green: 0.06, blue: 0.09))
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private var workspaceColor: Color {
        Color(red: 0.055, green: 0.06, blue: 0.085)
    }
}

// MARK: - Partition panel (separate view so @ObservedObject subscribes directly
// to FlashConfiguration.objectWillChange, triggering re-renders on isLoading changes)

private struct PartitionPanelView: View {
    @ObservedObject var config: FlashConfiguration

    var body: some View {
        VStack(spacing: 5) {
            ForEach($config.slots) { $slot in
                PartitionRowView(
                    slot: slot,
                    onBrowse: { browse(for: slot.id) },
                    onFilePicked: { url in config.setFile(url, for: slot.id) },
                    onClear: { config.clearFile(for: slot.id) }
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color(red: 0.055, green: 0.06, blue: 0.085))
    }

    private func browse(for slotID: String) {
        let panel = NSOpenPanel()
        panel.title = "Choose \(slotID) firmware file"
        panel.prompt = "Choose"
        panel.message = "Select a Samsung firmware archive or partition image."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        config.setFile(url, for: slotID)
    }
}
