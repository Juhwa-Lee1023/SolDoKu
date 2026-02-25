import SwiftUI
import UIKit

enum LegacyFlow: String, Hashable, CaseIterable {
    case camera
    case picker
    case manual

    var title: String {
        switch self {
        case .camera:
            return "Take a Picture".localized
        case .picker:
            return "Import from Album".localized
        case .manual:
            return "Direct Input".localized
        }
    }

    fileprivate var storyboardName: String {
        switch self {
        case .camera:
            return "photoSudoku"
        case .picker:
            return "pickerSudoku"
        case .manual:
            return "importSudoku"
        }
    }

    fileprivate var storyboardIdentifier: String {
        switch self {
        case .camera:
            return "photoSudoku"
        case .picker:
            return "pickerSudoku"
        case .manual:
            return "importSudoku"
        }
    }
}

protocol LegacyFlowViewControllerBuilding {
    func makeViewController(for flow: LegacyFlow) -> UIViewController
}

final class LegacyFlowViewControllerFactory: LegacyFlowViewControllerBuilding {
    func makeViewController(for flow: LegacyFlow) -> UIViewController {
        let storyboard = UIStoryboard(name: flow.storyboardName, bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: flow.storyboardIdentifier)
    }
}

struct LegacyFlowContainerView: UIViewControllerRepresentable {
    let flow: LegacyFlow
    let factory: LegacyFlowViewControllerBuilding

    func makeUIViewController(context: Context) -> UIViewController {
        factory.makeViewController(for: flow)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // no-op: this legacy screen manages its own UIKit state
    }
}
