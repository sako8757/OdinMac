import SwiftUI

struct DeviceStatusView: View {
    let isConnected: Bool
    let info: DeviceInfo?
    let flashState: FlashState

    var body: some View {
        HStack(spacing: 12) {
            connectionIndicator
            deviceDetails
            Spacer()
            stateLabel
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.08, green: 0.09, blue: 0.13))
    }

    private var connectionIndicator: some View {
        Circle()
            .fill(isConnected ? Color.green : Color.red.opacity(0.7))
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(isConnected ? Color.green.opacity(0.4) : Color.red.opacity(0.2), lineWidth: 3)
                    .scaleEffect(isConnected ? 1.6 : 1.0)
                    .opacity(isConnected ? 0.6 : 0)
            )
    }

    private var deviceDetails: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isConnected ? (info?.displayName ?? "Samsung Device") : "No Device")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isConnected ? .white : .gray)

            Text(isConnected
                 ? "Download Mode  |  \(info?.platform ?? "Unknown Platform")"
                 : "Connect device in Download Mode")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
    }

    private var stateLabel: some View {
        Group {
            switch flashState {
            case .idle:
                Text("READY")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
            case .connecting, .handshaking, .gettingDeviceInfo, .downloadingPIT:
                HStack(spacing: 5) {
                    ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                    Text(stateText)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
            case .flashing(let name, let progress):
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .frame(width: 80)
                        .tint(.accentColor)
                    Text("FLASHING \(name)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
            case .finishing:
                Text("FINISHING")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.yellow)
            case .success:
                Text("PASS")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(red: 0.3, green: 1.0, blue: 0.5))
            case .failed:
                Text("FAIL")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(.red)
            case .cancelled:
                Text("CANCELLED")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.orange)
            }
        }
    }

    private var stateText: String {
        switch flashState {
        case .connecting:         return "CONNECTING"
        case .handshaking:        return "HANDSHAKE"
        case .gettingDeviceInfo:  return "DEVICE INFO"
        case .downloadingPIT:     return "READING PIT"
        case .finishing:          return "FINISHING"
        default:                  return ""
        }
    }
}
