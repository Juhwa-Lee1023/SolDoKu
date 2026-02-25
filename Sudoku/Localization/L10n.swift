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

    enum Manual {
        static let clean = L10nToken("Clean")
        static let delete = L10nToken("Delete")
        static let solve = L10nToken("Solve")
        static let solving = L10nToken("Currently solving Sudoku")
        static let reallyWantToSolve = L10nToken("Really want to Solve?")
        static let requiresMoreThan17 = L10nToken("Sudoku Solve requires more than 17 numbers.")
        static let cannotSolve = L10nToken("Cannot solve Sudoku.")
        static let reenterSudoku = L10nToken("Do you want to re-enter Sudoku?")
        static let cleanSudoku = L10nToken("Clean Sudoku.")
        static let sudokuNotEntered = L10nToken("Sudoku has not Entered.")
    }

    enum Camera {
        static let shootAgain = L10nToken("Shoot Again")
        static let shootingSudoku = L10nToken("Shooting Sudoku")
        static let cameraGuide = L10nToken("Please look where Sudoku is located")
        static let solvingSudoku = L10nToken("Currently solving Sudoku")
        static let retryTitle = L10nToken("Fail.")
        static let retryMessage = L10nToken("Take a Picture Again.")
        static let permissionDeniedMessage = L10nToken("If didn't allow the camera permission, \r\n Would like to go to the Setting Screen?")
    }

    enum Image {
        static let uploadFromAlbum = L10nToken("Upload from Album")
        static let solvingSudoku = L10nToken("Solving Sudoku")
        static let imageMissingTitle = L10nToken("Picture hasn't been Uploaded.")
        static let imageMissingMessage = L10nToken("Want to Upload a Picture?")
        static let retryMessage = L10nToken("Upload another Picture?")
        static let albumPermissionDeniedMessage = L10nToken("Soldoku is not allowed access to Album. \r\n Do you want to go to the Setting Screen?")
    }

    enum Settings {
        static let title = L10nToken("Setting")
    }

    enum Common {
        static let yes = L10nToken("Yes")
        static let no = L10nToken("No")
        static let cancel = L10nToken("Cancel")
        static let confirm = L10nToken("Confirm")
    }
}
