import SwiftUI
import UniformTypeIdentifiers

struct PartitionRowView: View {
    let slot: PartitionSlot
    let onBrowse: () -> Void
    let onFilePicked: (URL) -> Void
    let onClear: () -> Void

    @State private var isTargeted = false

    private var hasError: Bool { slot.fileError != nil }

    var body: some View {
        HStack(spacing: 0) {
            // Label badge
            Text(slot.label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 76)
                .frame(maxHeight: .infinity)
                .background(labelBackground)
                .contentShape(Rectangle())
                .onTapGesture { onBrowse() }

            // File area
            HStack(spacing: 8) {
                Image(systemName: hasError ? "exclamationmark.triangle.fill"
                                 : (slot.hasFile ? "doc.fill" : "doc"))
                    .font(.system(size: 12))
                    .foregroundColor(hasError ? .red.opacity(0.75)
                                     : (slot.hasFile ? .accentColor : .gray.opacity(0.5)))

                VStack(alignment: .leading, spacing: 2) {
                    if hasError, let rejected = slot.rejectedFileName {
                        Text(rejected)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let err = slot.fileError {
                            Text(err)
                                .font(.system(size: 10))
                                .foregroundColor(.red.opacity(0.55))
                                .lineLimit(1)
                        }
                    } else {
                        Text(slot.hasFile ? slot.fileName
                                          : "Click to browse or drop a firmware file here")
                            .font(.system(size: 12, weight: slot.hasFile ? .medium : .regular))
                            .foregroundColor(slot.hasFile ? .white.opacity(0.9) : .gray.opacity(0.4))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if slot.hasFile {
                            secondaryLine
                        }
                    }
                }

                Spacer()

                if slot.isLoading {
                    ProgressView().scaleEffect(0.5).frame(width: 14, height: 14)
                } else if slot.hasFile || hasError {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background(hasError
                ? Color(red: 0.16, green: 0.08, blue: 0.08)
                : Color(red: 0.12, green: 0.13, blue: 0.20))
            .contentShape(Rectangle())
            .onTapGesture { if !hasError { onBrowse() } }
        }
        .frame(height: 47)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isTargeted ? Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.7)
                    : hasError  ? Color.red.opacity(0.35)
                    : slot.hasFile ? Color(red: 0.15, green: 0.4, blue: 0.9).opacity(0.25)
                    : Color.white.opacity(0.07),
                    lineWidth: isTargeted ? 1.5 : 1
                )
        )
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first(where: {
                $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            }) else { return false }
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.isFileURL else { return }
                DispatchQueue.main.async { onFilePicked(url) }
            }
            return true
        }
    }

    @ViewBuilder
    private var secondaryLine: some View {
        HStack(spacing: 6) {
            if slot.isLoading {
                Text("Reading…")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
            } else {
                if let fmt = formatBadge {
                    Text(fmt)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.09)))
                }
                if let size = slot.sizeString {
                    Text(size)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentColor.opacity(0.8))
                }
                if let summary = slot.contentsSummary {
                    Text("·").foregroundColor(.gray.opacity(0.3)).font(.system(size: 10))
                    Text(summary)
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(slot.contents?.joined(separator: "\n") ?? "")
                }
            }
        }
    }

    private var formatBadge: String? {
        let name = slot.fileName.lowercased()
        if name.hasSuffix(".tar.md5") { return "TAR.MD5" }
        if name.hasSuffix(".md5")     { return "MD5" }
        if name.hasSuffix(".tar")     { return "TAR" }
        if name.hasSuffix(".lz4")     { return "LZ4" }
        if name.hasSuffix(".img")     { return "IMG" }
        if name.hasSuffix(".bin")     { return "BIN" }
        return nil
    }

    private var labelBackground: Color {
        hasError       ? Color(red: 0.55, green: 0.10, blue: 0.10)
        : slot.hasFile ? Color(red: 0.12, green: 0.38, blue: 0.90)
        : Color(red: 0.09, green: 0.10, blue: 0.16)
    }
}
