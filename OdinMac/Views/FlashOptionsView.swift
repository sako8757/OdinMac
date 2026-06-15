import SwiftUI

struct FlashOptionsView: View {
    @ObservedObject var config: FlashConfiguration

    private enum DangerOption: Identifiable {
        case repartition, nandErase
        var id: String { switch self { case .repartition: return "rp"; case .nandErase: return "ne" } }

        var alertTitle: String {
            switch self {
            case .repartition: return "Enable Re-partition?"
            case .nandErase:   return "Enable NAND Erase All?"
            }
        }

        var alertMessage: String {
            switch self {
            case .repartition:
                return "This will REWRITE the device partition table using the selected PIT file.\n\n" +
                       "Only enable if the firmware release notes explicitly require it.\n\n" +
                       "Using the wrong PIT will permanently brick your device. There is no software recovery."
            case .nandErase:
                return "This will ERASE EVERY PARTITION: system, vendor, cache, and user data.\n\n" +
                       "Your device will not boot until all firmware is completely reflashed.\n\n" +
                       "Intended as a last resort only. Are you absolutely sure?"
            }
        }
    }

    @State private var pendingDanger: DangerOption? = nil

    var body: some View {
        HStack(spacing: 18) {
            compactToggle(
                "Reboot after flash",
                subtitle: "Auto-reboot on completion",
                binding: $config.rebootAfterFlash,
                accent: .white.opacity(0.85)
            )
            compactToggle(
                "Verify flash",
                subtitle: "Validate written data",
                binding: $config.verifyFlash,
                accent: .white.opacity(0.85)
            )

            Divider()
                .frame(height: 26)
                .background(Color.white.opacity(0.1))

            compactToggle(
                "Re-partition",
                subtitle: "Rewrites partition table ⚠",
                binding: Binding(
                    get: { config.repartition },
                    set: { if $0 { pendingDanger = .repartition } else { config.repartition = false } }
                ),
                accent: .orange.opacity(0.9)
            )
            compactToggle(
                "NAND Erase All",
                subtitle: "Erase ALL partitions ⚠⚠",
                binding: Binding(
                    get: { config.nandEraseAll },
                    set: { if $0 { pendingDanger = .nandErase } else { config.nandEraseAll = false } }
                ),
                accent: Color(red: 1.0, green: 0.35, blue: 0.2)
            )

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(red: 0.055, green: 0.06, blue: 0.085))
        .alert(item: $pendingDanger) { option in
            Alert(
                title: Text(option.alertTitle),
                message: Text(option.alertMessage),
                primaryButton: .destructive(Text("Enable Anyway")) {
                    switch option {
                    case .repartition: config.repartition = true
                    case .nandErase:   config.nandEraseAll = true
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func compactToggle(
        _ title: String,
        subtitle: String,
        binding: Binding<Bool>,
        accent: Color
    ) -> some View {
        HStack(spacing: 7) {
            Toggle(isOn: binding) { EmptyView() }
                .toggleStyle(.checkbox)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(binding.wrappedValue ? accent : .gray.opacity(0.6))
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.42))
            }
        }
    }
}
