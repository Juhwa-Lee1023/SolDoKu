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
    ],
    targets: [
        .target(
            name: "SudokuDomain",
            path: "Sources/SudokuDomain",
            sources: ["sudokuCalculation.swift"]
        ),
        .testTarget(
            name: "SudokuDomainTests",
            dependencies: ["SudokuDomain"],
            path: "Tests/SudokuDomainTests"
        ),
    ]
)
