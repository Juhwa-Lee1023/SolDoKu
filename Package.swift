// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SolDoKuDomain",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "SudokuDomain",
            targets: ["SudokuDomain"]
        ),
        .library(
            name: "DomainVision",
            targets: ["DomainVision"]
        ),
        .library(
            name: "SudokuInfrastructure",
            targets: ["SudokuInfrastructure"]
        ),
    ],
    targets: [
        .target(
            name: "SudokuDomain",
            path: "Sources/SudokuDomain"
        ),
        .target(
            name: "DomainVision",
            path: "Sources/DomainVision"
        ),
        .target(
            name: "SudokuInfrastructure",
            dependencies: [
                "SudokuDomain",
                "DomainVision",
            ],
            path: "Sources/SudokuInfrastructure"
        ),
        .testTarget(
            name: "SudokuDomainTests",
            dependencies: ["SudokuDomain"],
            path: "Tests/SudokuDomainTests"
        ),
        .testTarget(
            name: "SudokuInfrastructureTests",
            dependencies: [
                "SudokuInfrastructure",
                "DomainVision",
            ],
            path: "Tests/SudokuInfrastructureTests"
        ),
    ]
)
