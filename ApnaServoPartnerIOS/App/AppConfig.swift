import Foundation

enum AppConfig {
    static let apiBaseURL = URL(string: "https://apnaservobk-1.onrender.com/api")!
    static let socketURL = URL(string: "https://apnaservobk-1.onrender.com")!
    static let defaultCity = "Guwahati"
    static let defaultLatitude = 26.1445
    static let defaultLongitude = 91.7362
    static let refreshSeconds: UInt64 = 3_500_000_000
    static let locationHeartbeatSeconds: UInt64 = 10_000_000_000
    static let maxDocumentBytes = 4 * 1024 * 1024
}
