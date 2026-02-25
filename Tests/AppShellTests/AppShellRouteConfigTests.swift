import XCTest

final class AppShellRouteConfigTests: XCTestCase {
    func testHomeViewRoutesAllFlowsToSwiftUIFeatures() throws {
        let homeViewPath = repositoryRootURL()
            .appendingPathComponent("Sudoku")
            .appendingPathComponent("FeatureHome")
            .appendingPathComponent("HomeView.swift")
        let source = try String(contentsOf: homeViewPath, encoding: .utf8)

        XCTAssertTrue(source.contains("CameraSolveView()"))
        XCTAssertTrue(source.contains("ImageSolveView()"))
        XCTAssertTrue(source.contains("ManualSolveView()"))
        XCTAssertFalse(source.contains("LegacyFlowContainerView("))
    }

    func testLegacyFlowEnumStillExposesThreeHomeEntries() throws {
        let flowPath = repositoryRootURL()
            .appendingPathComponent("Sudoku")
            .appendingPathComponent("FeatureHome")
            .appendingPathComponent("LegacyFlowContainerView.swift")
        let source = try String(contentsOf: flowPath, encoding: .utf8)

        XCTAssertTrue(source.contains("case camera"))
        XCTAssertTrue(source.contains("case picker"))
        XCTAssertTrue(source.contains("case manual"))
    }

    func testProjectBuildPhaseExcludesLegacyUIKitFlowScreens() throws {
        let projectPath = repositoryRootURL()
            .appendingPathComponent("Sudoku.xcodeproj")
            .appendingPathComponent("project.pbxproj")
        let source = try String(contentsOf: projectPath, encoding: .utf8)

        XCTAssertFalse(source.contains("ViewController.swift in Sources"))
        XCTAssertFalse(source.contains("photoSudokuViewController.swift in Sources"))
        XCTAssertFalse(source.contains("pickerSudokuViewController.swift in Sources"))
        XCTAssertFalse(source.contains("importSudokuViewController.swift in Sources"))
    }

    func testProjectResourcesExcludeLegacyFlowStoryboards() throws {
        let projectPath = repositoryRootURL()
            .appendingPathComponent("Sudoku.xcodeproj")
            .appendingPathComponent("project.pbxproj")
        let source = try String(contentsOf: projectPath, encoding: .utf8)

        XCTAssertFalse(source.contains("Main.storyboard in Resources"))
        XCTAssertFalse(source.contains("photoSudoku.storyboard in Resources"))
        XCTAssertFalse(source.contains("pickerSudoku.storyboard in Resources"))
        XCTAssertFalse(source.contains("importSudoku.storyboard in Resources"))
    }

    private func repositoryRootURL(filePath: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent() // AppShellTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
    }
}
