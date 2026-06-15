import Foundation
import SwiftUI

enum LogLevel {
    case info, success, warning, error

    var color: Color {
        switch self {
        case .info:    return .white
        case .success: return Color(red: 0.3, green: 1.0, blue: 0.5)
        case .warning: return Color(red: 1.0, green: 0.8, blue: 0.2)
        case .error:   return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
    }

    var prefix: String {
        switch self {
        case .info:    return "INFO"
        case .success: return " OK "
        case .warning: return "WARN"
        case .error:   return "FAIL"
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: timestamp)
    }

    init(_ message: String, level: LogLevel = .info) {
        self.timestamp = Date()
        self.level = level
        self.message = message
    }
}
