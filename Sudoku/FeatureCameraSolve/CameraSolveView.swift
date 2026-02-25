import SwiftUI

struct CameraSolveView: View {
    @StateObject private var viewModel: CameraSolveViewModel

    init(viewModel: CameraSolveViewModel = .init()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(L10n.Camera.cameraGuide.localized)
                    .font(DSTypography.body)
                    .foregroundStyle(.secondary)

                cameraPreview
                    .frame(maxWidth: 420)
                    .aspectRatio(1, contentMode: .fit)

                resultPanel
                    .frame(maxWidth: 420)
                    .aspectRatio(1, contentMode: .fit)

                Button {
                    viewModel.primaryActionTapped()
                } label: {
                    Text(viewModel.primaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSPrimaryButtonStyle())
                .disabled(viewModel.isSolving)
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
        .navigationTitle(L10n.Home.takePicture.localized)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isSolving {
                solvingOverlay
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .alert(item: $viewModel.alertKind) { alert in
            buildAlert(for: alert)
        }
    }

    private var cameraPreview: some View {
        ZStack {
            CameraPreviewView(session: viewModel.cameraManager.session)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DSColor.gridBorder, lineWidth: 2)

            if viewModel.solvedImage != nil {
                Color.black.opacity(0.22)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var resultPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DSColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DSColor.gridBorder, lineWidth: 2)
                )

            if let solvedImage = viewModel.solvedImage {
                Image(uiImage: solvedImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(8)
            } else {
                Image("sudoku")
                    .resizable()
                    .scaledToFit()
                    .opacity(0.8)
                    .padding(24)
            }
        }
    }

    private var solvingOverlay: some View {
        ZStack {
            DSColor.loadingScrim
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text(L10n.Camera.solvingSudoku.localized)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func buildAlert(for alert: CameraSolveViewModel.AlertKind) -> Alert {
        switch alert {
        case .permissionDenied:
            return Alert(
                title: Text(L10n.Settings.title.localized),
                message: Text(L10n.Camera.permissionDeniedMessage.localized),
                primaryButton: .default(Text(L10n.Common.confirm.localized)) {
                    viewModel.openSettings()
                },
                secondaryButton: .cancel(Text(L10n.Common.cancel.localized))
            )

        case .insufficientDigits:
            return Alert(
                title: Text(L10n.Manual.reallyWantToSolve.localized),
                message: Text(L10n.Manual.requiresMoreThan17.localized),
                primaryButton: .default(Text(L10n.Common.yes.localized)) {
                    viewModel.solveIgnoringMinimumDigits()
                },
                secondaryButton: .destructive(Text(L10n.Common.no.localized)) {
                    viewModel.cancelSolveAndResumeCamera()
                }
            )

        case .solveFailed:
            return Alert(
                title: Text(L10n.Camera.retryTitle.localized),
                message: Text(L10n.Camera.retryMessage.localized),
                dismissButton: .default(Text(L10n.Common.confirm.localized))
            )
        }
    }
}
