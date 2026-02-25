import SwiftUI

struct HomeView: View {
    @State private var selectedPreviewIndex: Int?
    @State private var highlightedPreviewIndices: Set<Int> = []
    @State private var pressedPreviewIndex: Int?
    @State private var releasePressedPreviewWorkItem: DispatchWorkItem?

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let layout = LegacyHomeLayout(size: geometry.size)
                VStack(spacing: layout.buttonSpacing) {
                    Text(L10n.Home.title.localized)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(DSColor.title)
                        .minimumScaleFactor(0.5)
                        .padding(.top, layout.topPadding)

                    LegacySudokuPreviewGrid(
                        selectedIndex: selectedPreviewIndex,
                        highlightedIndices: highlightedPreviewIndices,
                        pressedIndex: pressedPreviewIndex,
                        onTapCell: selectPreviewCell
                    )
                    .frame(width: layout.boardSize, height: layout.boardSize)

                    VStack(spacing: layout.buttonSpacing) {
                        ForEach(LegacyFlow.allCases, id: \.self) { flow in
                            flowNavigationButton(for: flow, layout: layout)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.white.ignoresSafeArea())
            }
        }
    }

    @ViewBuilder
    private func flowNavigationButton(for flow: LegacyFlow, layout: LegacyHomeLayout) -> some View {
        NavigationLink {
            destinationView(for: flow)
        } label: {
            Text(flow.title.localized)
                .font(.system(size: 30, weight: .bold))
                .minimumScaleFactor(0.5)
                .foregroundStyle(Color.white)
                .frame(width: layout.boardSize, height: layout.buttonHeight)
                .background(Color(uiColor: .sudokuColor(.sudokuDeepButton)))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destinationView(for flow: LegacyFlow) -> some View {
        switch flow {
        case .camera:
            CameraSolveView()
        case .picker:
            ImageSolveView()
        case .manual:
            ManualSolveView()
        }
    }

    private func selectPreviewCell(_ index: Int) {
        guard index >= 0, index < 81 else { return }
        selectedPreviewIndex = index
        highlightedPreviewIndices = Self.makeHighlightedIndices(for: index)

        withAnimation(.easeOut(duration: 0.1)) {
            pressedPreviewIndex = index
        }

        releasePressedPreviewWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            guard pressedPreviewIndex == index else { return }
            withAnimation(.easeOut(duration: 0.1)) {
                pressedPreviewIndex = nil
            }
        }
        releasePressedPreviewWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }

    private static func makeHighlightedIndices(for selectedIndex: Int) -> Set<Int> {
        let selectCoordinate: [Int] = [selectedIndex / 9, selectedIndex % 9]
        let sectorRow: Int = 3 * Int(selectCoordinate[0] / 3)
        let sectorCol: Int = 3 * Int(selectCoordinate[1] / 3)
        let row1 = (selectCoordinate[0] + 2) % 3
        let row2 = (selectCoordinate[0] + 4) % 3
        let col1 = (selectCoordinate[1] + 2) % 3
        let col2 = (selectCoordinate[1] + 4) % 3

        var indices = Set<Int>()
        for i in 0..<81 {
            let cellCoordinate: [Int] = [i / 9, i % 9]
            if cellCoordinate[0] == selectCoordinate[0] {
                indices.insert(i)
            } else if cellCoordinate[1] == selectCoordinate[1] {
                indices.insert(i)
            }
            if (row1 + sectorRow) == cellCoordinate[0] && (col1 + sectorCol) == cellCoordinate[1] { indices.insert(i) }
            if (row2 + sectorRow) == cellCoordinate[0] && (col1 + sectorCol) == cellCoordinate[1] { indices.insert(i) }
            if (row1 + sectorRow) == cellCoordinate[0] && (col2 + sectorCol) == cellCoordinate[1] { indices.insert(i) }
            if (row2 + sectorRow) == cellCoordinate[0] && (col2 + sectorCol) == cellCoordinate[1] { indices.insert(i) }
        }
        return indices
    }
}

private struct LegacyHomeLayout {
    let size: CGSize

    var isNarrowScreen: Bool {
        guard size.height > 0 else { return true }
        return (size.width / size.height) <= (9.0 / 19.0)
    }

    var horizontalInset: CGFloat {
        isNarrowScreen ? (size.width / 20) : (size.width / 11)
    }

    var boardSize: CGFloat {
        max(0, size.width - (horizontalInset * 2))
    }

    var buttonHeight: CGFloat {
        boardSize / 6.5
    }

    var buttonSpacing: CGFloat {
        size.height / 35
    }

    var topPadding: CGFloat {
        isNarrowScreen ? 10 : 5
    }
}

private struct LegacySudokuPreviewGrid: View {
    let selectedIndex: Int?
    let highlightedIndices: Set<Int>
    let pressedIndex: Int?
    let onTapCell: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            let cellSize = side / 9
            let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 0), count: 9)

            ZStack {
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(0..<81, id: \.self) { index in
                        Rectangle()
                            .fill(backgroundColor(for: index))
                            .frame(width: cellSize, height: cellSize)
                            .scaleEffect(pressedIndex == index ? 0.9 : 1.0)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onTapCell(index)
                            }
                    }
                }

                LegacySudokuPreviewGridLines(cellSize: cellSize)
            }
        }
    }

    private func backgroundColor(for index: Int) -> Color {
        if selectedIndex == index {
            return Color(uiColor: .sudokuColor(.sudokuPurple))
        }

        if highlightedIndices.contains(index) {
            return Color(uiColor: .sudokuColor(.sudokuLightPurple))
        }

        return .white
    }
}

private struct LegacySudokuPreviewGridLines: View {
    let cellSize: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Path { path in
                    let x = CGFloat(index) * cellSize
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: cellSize * 9))
                }
                .stroke(Color.black, lineWidth: lineWidth(for: index))

                Path { path in
                    let y = CGFloat(index) * cellSize
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: cellSize * 9, y: y))
                }
                .stroke(Color.black, lineWidth: lineWidth(for: index))
            }
        }
    }

    private func lineWidth(for index: Int) -> CGFloat {
        switch index {
        case 0, 9:
            return 4
        case 3, 6:
            return 2
        default:
            return 1
        }
    }
}
