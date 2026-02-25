import SwiftUI

struct HomeView: View {
    private let flowFactory: LegacyFlowViewControllerBuilding
    @State private var alertModel: DSAlertModel?

    init(flowFactory: LegacyFlowViewControllerBuilding) {
        self.flowFactory = flowFactory
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [DSColor.surface, DSColor.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 22) {
                    Text(L10n.Home.title.localized)
                        .font(DSTypography.heroTitle)
                        .foregroundStyle(DSColor.title)
                        .minimumScaleFactor(0.8)

                    SudokuPreviewGrid()
                        .frame(maxWidth: 360)

                    VStack(spacing: 12) {
                        ForEach(LegacyFlow.allCases, id: \.self) { flow in
                            flowNavigationButton(for: flow)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .navigationTitle(L10n.Home.title.localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .dsAlert(model: $alertModel)
    }

    @ViewBuilder
    private func flowNavigationButton(for flow: LegacyFlow) -> some View {
        if flow == .manual {
            NavigationLink {
                ManualSolveView()
                    .navigationTitle(flow.title.localized)
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                Text(flow.title.localized)
            }
            .buttonStyle(DSPrimaryButtonStyle())
        } else if flow.isStoryboardAvailable {
            NavigationLink {
                LegacyFlowContainerView(flow: flow, factory: flowFactory)
                    .navigationTitle(flow.title.localized)
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                Text(flow.title.localized)
            }
            .buttonStyle(DSPrimaryButtonStyle())
        } else {
            Button {
                alertModel = DSAlertModel(
                    title: L10n.Alert.routeUnavailableTitle,
                    message: L10n.Alert.routeUnavailableMessage,
                    buttonText: L10n.Common.confirm
                )
            } label: {
                Text(flow.title.localized)
            }
            .buttonStyle(DSPrimaryButtonStyle())
        }
    }
}

private struct SudokuPreviewGrid: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<81, id: \.self) { index in
                Rectangle()
                    .fill(DSColor.surface)
                    .overlay(
                        Rectangle()
                            .strokeBorder(DSColor.gridLine, lineWidth: borderWidth(for: index))
                    )
                    .frame(height: 32)
            }
        }
        .background(DSColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(DSColor.gridBorder, lineWidth: 2)
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
