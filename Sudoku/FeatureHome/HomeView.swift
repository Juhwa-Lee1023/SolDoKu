import SwiftUI

struct HomeView: View {
    private let flowFactory: LegacyFlowViewControllerBuilding

    init(flowFactory: LegacyFlowViewControllerBuilding) {
        self.flowFactory = flowFactory
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                SudokuPreviewGrid()
                    .frame(maxWidth: 360)

                VStack(spacing: 12) {
                    ForEach(LegacyFlow.allCases, id: \.self) { flow in
                        NavigationLink {
                            LegacyFlowContainerView(flow: flow, factory: flowFactory)
                                .navigationTitle(flow.title)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            Text(flow.title)
                                .font(.system(size: 22, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .foregroundStyle(Color.white)
                                .background(Color(uiColor: .sudokuColor(.sudokuDeepButton)))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .navigationTitle("SolDoKu".localized)
        }
    }
}

private struct SudokuPreviewGrid: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<81, id: \.self) { index in
                Rectangle()
                    .fill(Color.white)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Color.black.opacity(0.9), lineWidth: borderWidth(for: index))
                    )
                    .frame(height: 32)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.black, lineWidth: 2)
        )
    }

    private func borderWidth(for index: Int) -> CGFloat {
        let row = index / 9
        let col = index % 9
        if row % 3 == 0 || col % 3 == 0 {
            return 1.5
        }
        return 0.5
    }
}
