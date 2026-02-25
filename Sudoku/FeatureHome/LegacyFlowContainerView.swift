import SwiftUI
import UIKit

enum LegacyFlow: String, Hashable, CaseIterable {
    case camera
    case picker
    case manual

    var title: L10nToken {
        switch self {
        case .camera:
            return L10n.Home.takePicture
        case .picker:
            return L10n.Home.importFromAlbum
        case .manual:
            return L10n.Home.directInput
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

    var isStoryboardAvailable: Bool {
        Bundle.main.path(forResource: storyboardName, ofType: "storyboardc") != nil
    }
}

protocol LegacyFlowViewControllerBuilding {
    func makeViewController(for flow: LegacyFlow) -> UIViewController
}

final class LegacyFlowViewControllerFactory: LegacyFlowViewControllerBuilding {
    func makeViewController(for flow: LegacyFlow) -> UIViewController {
        let storyboard = UIStoryboard(name: flow.storyboardName, bundle: nil)
        guard let viewController = storyboard.instantiateInitialViewController() else {
            assertionFailure("missing initial view controller for \(flow.storyboardName)")
            return LegacyFlowUnavailableViewController(flowTitle: flow.title.localized)
        }
        return viewController
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

private final class LegacyFlowUnavailableViewController: UIViewController {
    private let flowTitle: String

    init(flowTitle: String) {
        self.flowTitle = flowTitle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = flowTitle

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = L10n.Alert.routeUnavailableMessage.localized
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
