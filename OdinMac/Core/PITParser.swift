import Foundation

struct PITEntry {
    var binaryType: UInt32    // 0=PDA, 1=Phone, 2=CSC, 3=CP
    var deviceType: UInt32    // 0=OneNAND, 1=File, 2=MMC, 3=All
    var identifier: UInt32
    var attributes: UInt32
    var updateAttributes: UInt32
    var blockSizeOrOffset: UInt32
    var blockCount: UInt32
    var fileOffset: UInt32
    var fileSize: UInt32
    var partitionName: String
    var flashFileName: String
    var fotaFileName: String

    var sizeBytes: UInt64 { UInt64(blockCount) * 512 }
    var sizeMB: Double { Double(sizeBytes) / 1_048_576 }
}

struct PITTable {
    var magicNumber: UInt32
    var entryCount: UInt32
    var unknown1: UInt32
    var unknown2: UInt32
    var unknown3: UInt32
    var entries: [PITEntry]

    static let kMagicNumber: UInt32 = 0x12349876
    static let kEntrySize: Int = 132

    var isValid: Bool { magicNumber == PITTable.kMagicNumber }
}

enum PITParseError: LocalizedError {
    case invalidMagic
    case truncatedData
    case invalidEntry

    var errorDescription: String? {
        switch self {
        case .invalidMagic:   return "Invalid PIT magic number"
        case .truncatedData:  return "PIT data is truncated"
        case .invalidEntry:   return "Invalid PIT entry"
        }
    }
}

final class PITParser {
    static func parse(_ data: Data) throws -> PITTable {
        guard data.count >= 28 else { throw PITParseError.truncatedData }

        let magic = data.uint32(at: 0)
        guard magic == PITTable.kMagicNumber else { throw PITParseError.invalidMagic }

        let entryCount = data.uint32(at: 4)
        guard data.count >= 28 + Int(entryCount) * PITTable.kEntrySize else {
            throw PITParseError.truncatedData
        }

        var entries: [PITEntry] = []
        for i in 0..<Int(entryCount) {
            let base = 28 + i * PITTable.kEntrySize
            let entry = try parseEntry(data, at: base)
            entries.append(entry)
        }

        return PITTable(
            magicNumber: magic,
            entryCount: entryCount,
            unknown1: data.uint32(at: 8),
            unknown2: data.uint32(at: 12),
            unknown3: data.uint32(at: 16),
            entries: entries
        )
    }

    private static func parseEntry(_ data: Data, at offset: Int) throws -> PITEntry {
        guard data.count >= offset + PITTable.kEntrySize else {
            throw PITParseError.truncatedData
        }

        func str(from start: Int, maxLen: Int) -> String {
            let end = min(start + maxLen, data.count)
            let sub = data.subdata(in: start..<end)
            if let nul = sub.firstIndex(of: 0) {
                return String(data: sub.prefix(nul - sub.startIndex), encoding: .ascii) ?? ""
            }
            return String(data: sub, encoding: .ascii) ?? ""
        }

        return PITEntry(
            binaryType:         data.uint32(at: offset + 0),
            deviceType:         data.uint32(at: offset + 4),
            identifier:         data.uint32(at: offset + 8),
            attributes:         data.uint32(at: offset + 12),
            updateAttributes:   data.uint32(at: offset + 16),
            blockSizeOrOffset:  data.uint32(at: offset + 20),
            blockCount:         data.uint32(at: offset + 24),
            fileOffset:         data.uint32(at: offset + 28),
            fileSize:           data.uint32(at: offset + 32),
            partitionName:      str(from: offset + 36, maxLen: 32),
            flashFileName:      str(from: offset + 68, maxLen: 32),
            fotaFileName:       str(from: offset + 100, maxLen: 32)
        )
    }
}

private extension Data {
    func uint32(at offset: Int) -> UInt32 {
        guard count >= offset + 4 else { return 0 }
        return subdata(in: offset..<(offset + 4))
            .withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
    }
}
