import SwiftUI

@main
struct SudokuApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let compositionRoot = AppCompositionRoot()

    var body: some Scene {
        WindowGroup {
            compositionRoot.makeRootView()
        }
    }
}
