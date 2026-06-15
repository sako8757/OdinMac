import SwiftUI
import AppKit

struct LogView: View {
    let entries: [LogEntry]
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.gray.opacity(0.3))
            scrollContent
        }
        .background(Color(red: 0.055, green: 0.06, blue: 0.085))
    }

    private var header: some View {
        HStack {
            Text("Log")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.gray)
            Spacer()
            Button {
                let text = entries
                    .map { "[\($0.timeString)] \($0.level.prefix) \($0.message)" }
                    .joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                    Text("Copy")
                        .font(.system(size: 10))
                }
                .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .help("Copy all log entries to clipboard")
            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.checkbox)
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .padding(.leading, 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var scrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(entries) { entry in
                        logRow(entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onChange(of: entries.count) { _ in
                if autoScroll, let last = entries.last {
                    withAnimation(.none) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.timeString)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.gray.opacity(0.6))
                .frame(width: 50, alignment: .leading)

            Text(entry.level.prefix)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))

            Text(entry.message)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(entry.level.color)
                .textSelection(.enabled)
        }
    }
}
