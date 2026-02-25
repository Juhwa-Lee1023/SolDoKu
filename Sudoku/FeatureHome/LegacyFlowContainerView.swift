import Foundation

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
}
