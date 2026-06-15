import Foundation

struct FlashPartition: Equatable {
    let name: String
    let file: URL
}

struct FlashPartitionPlan {
    private(set) var partitions: [FlashPartition] = []
    private var indexByName: [String: Int] = [:]

    /// Adds a partition while keeping Heimdall arguments unique. Later firmware
    /// slots replace earlier ones, so a patched AP can override stock BL images.
    mutating func add(_ partition: FlashPartition) -> FlashPartition? {
        let key = partition.name.lowercased()
        guard let index = indexByName[key] else {
            indexByName[key] = partitions.count
            partitions.append(partition)
            return nil
        }

        let replaced = partitions[index]
        partitions[index] = partition
        return replaced
    }
}
