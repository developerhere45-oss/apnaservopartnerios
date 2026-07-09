import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct ApnaServoPartnerIOSApp: App {
    @StateObject private var store = PartnerAppStore()

    init() {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
