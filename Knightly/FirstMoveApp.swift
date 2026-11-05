import SwiftUI

enum AppConfig {
    private static func flag(_ key: String) -> Bool {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? Bool { return value }
        let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "").lowercased()
        return ["yes", "true", "1"].contains(value)
    }
    static var cloudEnabled: Bool { flag("FirstMoveCloudEnabled") }
    static var appleSignInEnabled: Bool { flag("FirstMoveAppleSignInEnabled") }
}

@main
struct FirstMoveApp: App {
    @StateObject private var progress: ProgressStore
    @StateObject private var account = AccountSession()
    @Environment(\.scenePhase) private var scenePhase
    private let catalog = CourseCatalog()

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-firstmove-ui-test-reset") {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("FirstMove", isDirectory: true)
            try? FileManager.default.removeItem(at: directory)
        }
        #endif
        _progress = StateObject(wrappedValue: ProgressStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView(catalog: catalog)
                .environmentObject(progress)
                .environmentObject(account)
                .tint(Palette.forest)
                .preferredColorScheme(.light)
                .onAppear {
                    progress.switchAccount(id: account.currentUserID)
                    account.checkCredentialState()
                }
                .onChange(of: account.currentUserID) { _, id in
                    progress.switchAccount(id: id)
                    if let name = account.displayName, !name.isEmpty {
                        progress.profileName = name
                        progress.savePreferences()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        progress.refreshSync()
                        account.checkCredentialState()
                    }
                }
        }
    }
}
