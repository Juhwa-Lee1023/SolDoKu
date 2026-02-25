import SwiftUI

struct AppCompositionRoot {
    private let legacyFactory: LegacyFlowViewControllerFactory

    init(legacyFactory: LegacyFlowViewControllerFactory = .init()) {
        self.legacyFactory = legacyFactory
    }

    @ViewBuilder
    func makeRootView() -> some View {
        HomeView(flowFactory: legacyFactory)
    }
}
