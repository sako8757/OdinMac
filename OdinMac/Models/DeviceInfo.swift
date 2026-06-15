import Foundation

struct DeviceInfo: Equatable {
    var productName: String = "Unknown"
    var version: String = "Unknown"
    var platform: String = "Unknown"
    var cpuId: String = "Unknown"
    var serialNo: String = "Unknown"
    var isSecure: Bool = false

    var displayName: String { productName.isEmpty ? "Samsung Device" : productName }
}
