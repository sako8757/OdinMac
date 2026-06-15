import Foundation

struct PartitionSlot: Identifiable {
    let id: String
    let label: String
    var fileURL: URL?
    var isEnabled: Bool

    // Populated asynchronously after a file is chosen.
    var isLoading: Bool = false
    var fileSize: Int64? = nil
    var contents: [String]? = nil       // partition images found inside the archive

    // Set when the user drops/selects a file with an unsupported extension.
    var fileError: String? = nil
    var rejectedFileName: String? = nil

    var fileName: String { fileURL?.lastPathComponent ?? "No File" }
    var hasFile: Bool { fileURL != nil }

    var sizeString: String? {
        guard let s = fileSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: s, countStyle: .file)
    }

    /// Short summary of what's inside, e.g. "boot, recovery, super (+3)".
    var contentsSummary: String? {
        guard let c = contents, !c.isEmpty else { return nil }
        let shown = c.prefix(3).map { ($0 as NSString).deletingPathExtension }
        let extra = c.count - shown.count
        return shown.joined(separator: ", ") + (extra > 0 ? "  (+\(extra))" : "")
    }
}

class FlashConfiguration: ObservableObject {
    /// Optional callback to push log messages into the app's log panel.
    var onLog: ((String, LogLevel) -> Void)?
    @Published var slots: [PartitionSlot] = [
        PartitionSlot(id: "BL",       label: "BL",       fileURL: nil, isEnabled: false),
        PartitionSlot(id: "AP",       label: "AP",       fileURL: nil, isEnabled: true),
        PartitionSlot(id: "CP",       label: "CP",       fileURL: nil, isEnabled: false),
        PartitionSlot(id: "CSC",      label: "CSC",      fileURL: nil, isEnabled: false),
        PartitionSlot(id: "USERDATA", label: "USERDATA", fileURL: nil, isEnabled: false),
    ]

    @Published var repartition: Bool = false
    @Published var rebootAfterFlash: Bool = true
    @Published var verifyFlash: Bool = true
    @Published var nandEraseAll: Bool = false

    var hasAnyFile: Bool { slots.contains { $0.fileURL != nil } }

    private static let validSuffixes = [".tar.md5", ".tar", ".md5", ".img", ".bin", ".lz4", ".mbn"]

    func setFile(_ url: URL, for slotID: String) {
        guard let idx = slots.firstIndex(where: { $0.id == slotID }) else { return }
        let name = url.lastPathComponent.lowercased()
        guard Self.validSuffixes.contains(where: { name.hasSuffix($0) }) else {
            let ext = url.pathExtension.isEmpty ? "unknown" : ".\(url.pathExtension)"
            let msg = "Unsupported format (\(ext)). Accepted: .tar.md5  .tar  .img  .bin  .lz4  .mbn"
            slots[idx].fileError = msg
            slots[idx].rejectedFileName = url.lastPathComponent
            slots[idx].fileURL = nil
            slots[idx].isEnabled = false
            onLog?("[\(slotID)] Rejected \(url.lastPathComponent): \(msg)", .error)
            return
        }
        slots[idx].fileError = nil
        slots[idx].rejectedFileName = nil
        slots[idx].fileURL = url
        slots[idx].isEnabled = true
        slots[idx].isLoading = true
        slots[idx].fileSize = nil
        slots[idx].contents = nil
        onLog?("[\(slotID)] Reading \(url.lastPathComponent)…", .info)
        loadMetadata(for: slotID, url: url)
    }

    func clearFile(for slotID: String) {
        guard let idx = slots.firstIndex(where: { $0.id == slotID }) else { return }
        slots[idx].fileURL = nil
        slots[idx].isEnabled = false
        slots[idx].isLoading = false
        slots[idx].fileSize = nil
        slots[idx].contents = nil
        slots[idx].fileError = nil
        slots[idx].rejectedFileName = nil
    }

    func reset() {
        for idx in slots.indices {
            slots[idx].fileURL = nil
            slots[idx].isEnabled = slots[idx].id == "AP"
            slots[idx].isLoading = false
            slots[idx].fileSize = nil
            slots[idx].contents = nil
            slots[idx].fileError = nil
            slots[idx].rejectedFileName = nil
        }
    }

    // MARK: - Background metadata

    /// Reads file size and peeks the archive's contents off the main thread,
    /// then publishes the result so the row can show size + what's inside.
    private func loadMetadata(for slotID: String, url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int64
            let contents = Self.peekArchive(url)
            DispatchQueue.main.async {
                guard let idx = self.slots.firstIndex(where: { $0.id == slotID }),
                      self.slots[idx].fileURL == url else { return }   // selection changed meanwhile
                self.slots[idx].fileSize = size
                self.slots[idx].contents = contents
                self.slots[idx].isLoading = false
                let sizeStr = size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "unknown size"
                let parts = contents.prefix(5).joined(separator: ", ")
                self.onLog?("[\(slotID)] Loaded \(sizeStr)  ·  \(parts)", .success)
                NSLog("[OdinMac] [\(slotID)] Loaded: size=\(sizeStr) parts=\(parts)")
            }
        }
    }

    /// Lists the image files inside a .tar/.tar.md5 (fast: tar seeks past data).
    /// Returns [filename] for a bare .img/.bin, or [] if it can't be read.
    private static func peekArchive(_ url: URL) -> [String] {
        let ext = url.pathExtension.lowercased()
        if ext == "img" || ext == "bin" || ext == "lz4" || ext == "mbn" {
            return [url.lastPathComponent]
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        proc.arguments = ["-tf", url.path]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            // Accept exit code 1 (warnings, e.g. trailing MD5 on .tar.md5 files).
            guard proc.terminationStatus <= 1, let out = String(data: data, encoding: .utf8) else {
                return [url.lastPathComponent]
            }
            return out.split(separator: "\n")
                .map { ($0 as Substring).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasSuffix("/") }
                .map { ($0 as NSString).lastPathComponent }
        } catch {
            return [url.lastPathComponent]
        }
    }
}
