import XCTest

final class AppShellRouteConfigTests: XCTestCase {
    func testLegacyFlowStoryboardsDeclareInitialViewController() throws {
        let root = repositoryRootURL()
        let expectedStoryboards = ["photoSudoku", "pickerSudoku", "importSudoku"]

        for storyboardName in expectedStoryboards {
            let storyboardPath = root
                .appendingPathComponent("Sudoku")
                .appendingPathComponent("StoryBoard")
                .appendingPathComponent("\(storyboardName).storyboard")

            let xml = try String(contentsOf: storyboardPath, encoding: .utf8)
            XCTAssertTrue(
                xml.contains("initialViewController=\""),
                "\(storyboardName).storyboard must define initialViewController for SwiftUI bridge routing"
            )
        }
    }

    func testMainStoryboardReferencesAllLegacyFlows() throws {
        let mainStoryboardPath = repositoryRootURL()
            .appendingPathComponent("Sudoku")
            .appendingPathComponent("StoryBoard")
            .appendingPathComponent("Base.lproj")
            .appendingPathComponent("Main.storyboard")
        let xml = try String(contentsOf: mainStoryboardPath, encoding: .utf8)

        XCTAssertTrue(xml.contains("storyboardName=\"photoSudoku\""))
        XCTAssertTrue(xml.contains("storyboardName=\"pickerSudoku\""))
        XCTAssertTrue(xml.contains("storyboardName=\"importSudoku\""))
    }

    private func repositoryRootURL(filePath: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent() // AppShellTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
    }
}
