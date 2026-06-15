import SwiftUI

struct InfoPanelView: View {
    @ObservedObject var config: FlashConfiguration

    private var activeSlots: [PartitionSlot] {
        config.slots.filter { $0.hasFile }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {

                // Partition guide
                sectionHeader("PARTITION GUIDE", icon: "list.bullet.rectangle")
                    .padding(.bottom, 7)

                ForEach(config.slots, id: \.id) { slot in
                    slotRow(slot)
                        .padding(.bottom, 8)
                }

                // Will flash (dynamic)
                if !activeSlots.isEmpty {
                    sectionDivider()
                    sectionHeader("WILL FLASH", icon: "bolt.fill")
                        .padding(.bottom, 7)
                    ForEach(activeSlots, id: \.id) { slot in
                        flashEffectRow(slot)
                            .padding(.bottom, 6)
                    }
                }

                sectionDivider()
                sectionHeader("OPTIONS", icon: "gearshape")
                    .padding(.bottom, 7)
                ForEach(optionsInfo, id: \.title) { info in
                    optionRow(info)
                        .padding(.bottom, 6)
                }

                sectionDivider()
                sectionHeader("BEFORE YOU FLASH", icon: "exclamationmark.triangle.fill", color: .orange)
                    .padding(.bottom, 7)
                ForEach(safetyWarnings, id: \.self) { warning in
                    warningRow(warning)
                }
            }
            .padding(12)
        }
        .background(Color(red: 0.045, green: 0.05, blue: 0.07))
    }

    // MARK: - Slot row

    private func slotRow(_ slot: PartitionSlot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(slot.label)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(slot.hasFile
                        ? Color(red: 0.2, green: 0.6, blue: 1.0)
                        : .white.opacity(0.6))
                    .frame(width: 58, alignment: .leading)
                Text(slotFullName(slot.id))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                if slot.hasFile {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green.opacity(0.7))
                }
            }
            Text(slotDesc(slot.id))
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }

    // MARK: - Flash effect row

    private func flashEffectRow(_ slot: PartitionSlot) -> some View {
        let (effect, isWarning) = flashEffect(slot.id)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(slot.label)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                Text(slot.fileName)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let size = slot.sizeString {
                    Spacer()
                    Text(size)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.45))
                }
            }
            Text(effect)
                .font(.system(size: 10))
                .foregroundColor(isWarning ? .red.opacity(0.75) : .green.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
            if let summary = slot.contentsSummary {
                Text("Partitions: \(summary)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.42))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    // MARK: - Option and warning rows

    private struct OptionInfo {
        let title: String
        let desc: String
        let danger: Bool
    }

    private func optionRow(_ info: OptionInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(info.title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(info.danger ? .orange.opacity(0.8) : .white.opacity(0.6))
            Text(info.desc)
                .font(.system(size: 8))
                .foregroundColor(.gray.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(1)
        }
    }

    private func warningRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Text("•")
                .font(.system(size: 8))
                .foregroundColor(.orange.opacity(0.5))
            Text(text)
                .font(.system(size: 8))
                .foregroundColor(.gray.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(1)
        }
        .padding(.bottom, 3)
    }

    // MARK: - Section helpers

    private func sectionHeader(_ title: String, icon: String, color: Color = Color(red: 0.2, green: 0.5, blue: 1.0)) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color.opacity(0.55))
                .frame(width: 2, height: 11)
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color.opacity(0.55))
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.gray.opacity(0.45))
        }
    }

    private func sectionDivider() -> some View {
        Divider()
            .background(Color.white.opacity(0.06))
            .padding(.vertical, 9)
    }

    // MARK: - Static data

    private func slotFullName(_ id: String) -> String {
        switch id {
        case "BL":       return "Bootloader"
        case "AP":       return "Application Processor"
        case "CP":       return "Cell Processor (Modem)"
        case "CSC":      return "Consumer SW Customization"
        case "USERDATA": return "User Data"
        default:         return id
        }
    }

    private func slotDesc(_ id: String) -> String {
        switch id {
        case "BL":
            return "Secure boot chain and hardware initialisation. Wrong BL can hard-brick the device. Always match the exact model number."
        case "AP":
            return "Main OS package: kernel, system, vendor, recovery, and boot images. Usually the largest file (1–5 GB)."
        case "CP":
            return "Cellular radio and baseband firmware. Flash with model-matched firmware to avoid call and data issues."
        case "CSC":
            return "Region and carrier settings. HOME_CSC preserves user data; plain CSC performs a full factory reset."
        case "USERDATA":
            return "Factory-data partition. Flashing this ERASES ALL personal data, apps, and settings. Permanently."
        default:
            return ""
        }
    }

    private func flashEffect(_ id: String) -> (String, Bool) {
        switch id {
        case "BL":       return ("↳ Updates secure boot chain and bootloader stages", false)
        case "AP":       return ("↳ Flashes OS kernel, system, vendor, recovery, and boot partitions", false)
        case "CP":       return ("↳ Updates cellular radio and baseband firmware", false)
        case "CSC":      return ("↳ Updates region / carrier settings (HOME_CSC keeps your data)", false)
        case "USERDATA": return ("↳ ⚠ ERASES ALL USER DATA (equivalent to factory reset)", true)
        default:         return ("", false)
        }
    }

    private let optionsInfo: [OptionInfo] = [
        OptionInfo(
            title: "Reboot after flash",
            desc: "Auto-reboots the device when flashing completes.",
            danger: false
        ),
        OptionInfo(
            title: "Verify flash",
            desc: "Validates each partition after writing. Recommended.",
            danger: false
        ),
        OptionInfo(
            title: "Re-partition  ⚠",
            desc: "Rewrites the partition table using the PIT file. Wrong PIT can permanently brick the device.",
            danger: true
        ),
        OptionInfo(
            title: "NAND Erase All  ⚠⚠",
            desc: "Erases every partition before flashing. Last resort only.",
            danger: true
        ),
    ]

    private let safetyWarnings: [String] = [
        "Always match firmware to the exact device model.",
        "Wrong BL can permanently brick the device.",
        "HOME_CSC preserves data; plain CSC performs a factory reset.",
        "Keep the USB cable connected throughout the flash.",
        "Enable Re-partition only when explicitly required.",
        "NAND Erase All is a last-resort option.",
    ]

}
