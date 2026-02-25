import SwiftUI

struct ManualSolveView: View {
    @StateObject private var viewModel: ManualSolveViewModel

    init(viewModel: ManualSolveViewModel = .init()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ManualSudokuGrid(
                    values: viewModel.board,
                    selectedIndex: viewModel.selectedIndex,
                    highlightedIndices: viewModel.highlightedIndices,
                    conflictingIndices: viewModel.conflictingIndices,
                    onTapCell: { index in
                        if !viewModel.isSolving {
                            viewModel.selectCell(at: index)
                        }
                    }
                )
                .frame(maxWidth: 420)

                ManualKeypad(
                    blockedDigits: viewModel.blockedDigits,
                    isSolving: viewModel.isSolving,
                    onTapDigit: { digit in
                        viewModel.inputDigit(digit)
                    },
                    onTapClean: {
                        viewModel.requestCleanBoard()
                    },
                    onTapDelete: {
                        viewModel.deleteSelectedCellValue()
                    },
                    onTapSolve: {
                        viewModel.solveButtonTapped()
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [DSColor.surface, DSColor.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(L10n.Home.directInput.localized)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isSolving {
                ManualSolveLoadingOverlay()
            }
        }
        .alert(item: $viewModel.alertKind) { alert in
            buildAlert(for: alert)
        }
    }

    private func buildAlert(for alert: ManualSolveViewModel.AlertKind) -> Alert {
        switch alert {
        case .cleanConfirm:
            return Alert(
                title: Text(L10n.Manual.cleanSudoku.localized),
                message: Text(L10n.Manual.reenterSudoku.localized),
                primaryButton: .default(Text(L10n.Common.yes.localized)) {
                    viewModel.clearBoard()
                },
                secondaryButton: .destructive(Text(L10n.Common.no.localized))
            )

        case .insufficientDigits:
            return Alert(
                title: Text(L10n.Manual.reallyWantToSolve.localized),
                message: Text(L10n.Manual.requiresMoreThan17.localized),
                primaryButton: .default(Text(L10n.Common.yes.localized)) {
                    viewModel.solveIgnoringMinimumDigits()
                },
                secondaryButton: .destructive(Text(L10n.Common.no.localized))
            )

        case .unsolvable:
            return Alert(
                title: Text(L10n.Manual.cannotSolve.localized),
                message: Text(L10n.Manual.reenterSudoku.localized),
                primaryButton: .default(Text(L10n.Common.yes.localized)) {
                    viewModel.clearBoard()
                },
                secondaryButton: .destructive(Text(L10n.Common.no.localized))
            )

        case .emptyBoard:
            return Alert(
                title: Text(L10n.Manual.sudokuNotEntered.localized),
                message: Text(L10n.Alert.routeUnavailableMessage.localized),
                dismissButton: .default(Text(L10n.Common.confirm.localized))
            )
        }
    }
}

private struct ManualSudokuGrid: View {
    let values: [Int]
    let selectedIndex: Int?
    let highlightedIndices: Set<Int>
    let conflictingIndices: Set<Int>
    let onTapCell: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            let cellSize = side / 9
            let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 0), count: 9)

            ZStack {
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(0..<81, id: \.self) { index in
                        Button {
                            onTapCell(index)
                        } label: {
                            Text(displayText(for: values[index]))
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(width: cellSize, height: cellSize)
                                .background(backgroundColor(for: index))
                        }
                        .buttonStyle(.plain)
                    }
                }

                ManualGridLines(cellSize: cellSize)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DSColor.gridBorder, lineWidth: 2)
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func displayText(for value: Int) -> String {
        value == 0 ? "" : String(value)
    }

    private func backgroundColor(for index: Int) -> Color {
        if selectedIndex == index {
            return DSColor.manualSelectedCell
        }

        if conflictingIndices.contains(index) {
            return DSColor.manualConflictingCell
        }

        if highlightedIndices.contains(index) {
            return DSColor.manualRelatedCell
        }

        return DSColor.surface
    }
}

private struct ManualGridLines: View {
    let cellSize: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Path { path in
                    let x = CGFloat(index) * cellSize
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: cellSize * 9))
                }
                .stroke(DSColor.gridBorder, lineWidth: lineWidth(for: index))

                Path { path in
                    let y = CGFloat(index) * cellSize
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: cellSize * 9, y: y))
                }
                .stroke(DSColor.gridBorder, lineWidth: lineWidth(for: index))
            }
        }
    }

    private func lineWidth(for index: Int) -> CGFloat {
        index.isMultiple(of: 3) ? 2 : 0.4
    }
}

private struct ManualKeypad: View {
    let blockedDigits: Set<Int>
    let isSolving: Bool
    let onTapDigit: (Int) -> Void
    let onTapClean: () -> Void
    let onTapDelete: () -> Void
    let onTapSolve: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    private let keypadItems: [ManualKeypadItem] = [
        .digit(1), .digit(2), .digit(3), .action(.clean),
        .digit(4), .digit(5), .digit(6), .action(.delete),
        .digit(7), .digit(8), .digit(9), .action(.solve),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(keypadItems, id: \.self) { item in
                Button {
                    tap(item)
                } label: {
                    Text(title(for: item))
                        .font(font(for: item))
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DSColor.primaryButtonForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(backgroundColor(for: item))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSolving)
            }
        }
    }

    private func tap(_ item: ManualKeypadItem) {
        switch item {
        case .digit(let digit):
            onTapDigit(digit)
        case .action(let action):
            switch action {
            case .clean:
                onTapClean()
            case .delete:
                onTapDelete()
            case .solve:
                onTapSolve()
            }
        }
    }

    private func title(for item: ManualKeypadItem) -> String {
        switch item {
        case .digit(let digit):
            return String(digit)
        case .action(let action):
            switch action {
            case .clean:
                return L10n.Manual.clean.localized
            case .delete:
                return L10n.Manual.delete.localized
            case .solve:
                return L10n.Manual.solve.localized
            }
        }
    }

    private func font(for item: ManualKeypadItem) -> Font {
        switch item {
        case .digit:
            return .system(size: 26, weight: .bold, design: .rounded)
        case .action:
            return .system(size: 18, weight: .semibold, design: .rounded)
        }
    }

    private func backgroundColor(for item: ManualKeypadItem) -> Color {
        switch item {
        case .digit(let digit):
            if blockedDigits.contains(digit) {
                return DSColor.manualBlockedDigitButton
            }
            return DSColor.primaryButton

        case .action(let action):
            switch action {
            case .clean, .delete, .solve:
                return DSColor.primaryButton
            }
        }
    }
}

private struct ManualSolveLoadingOverlay: View {
    var body: some View {
        ZStack {
            DSColor.loadingScrim
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text(L10n.Manual.solving.localized)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private enum ManualKeypadItem: Hashable {
    case digit(Int)
    case action(ManualKeypadAction)
}

private enum ManualKeypadAction: Hashable {
    case clean
    case delete
    case solve
}
