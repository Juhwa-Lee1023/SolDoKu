import Foundation

struct L10nToken: Hashable {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var localized: String {
        key.localized
    }
}

enum L10n {
    enum Home {
        static let title = L10nToken("SolDoKu")
        static let takePicture = L10nToken("Take a Picture")
        static let importFromAlbum = L10nToken("Import from Album")
        static let directInput = L10nToken("Direct Input")
    }

    enum Alert {
        static let routeUnavailableTitle = L10nToken("Fail.")
        static let routeUnavailableMessage = L10nToken("Please enter Sudoku.")
    }

    enum Common {
        static let confirm = L10nToken("Confirm")
    }
}
