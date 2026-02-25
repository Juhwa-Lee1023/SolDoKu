import PhotosUI
import SwiftUI

struct ImageSolveView: View {
    @StateObject private var viewModel: ImageSolveViewModel
    @State private var pickerItem: PhotosPickerItem?

    init(viewModel: ImageSolveViewModel = .init()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                imageCanvas
                    .frame(maxWidth: 420)
                    .aspectRatio(1, contentMode: .fit)

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(L10n.Image.uploadFromAlbum.localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSPrimaryButtonStyle())
                .disabled(viewModel.isSolving)

                Button {
                    viewModel.solveButtonTapped()
                } label: {
                    Text(L10n.Image.solvingSudoku.localized)
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
        .navigationTitle(L10n.Home.importFromAlbum.localized)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isSolving {
                solvingOverlay
            }
        }
        .onAppear {
            viewModel.requestPhotoPermissionAndThen {}
        }
        .onChange(of: pickerItem) { newValue in
            guard let newValue else { return }
            Task {
                do {
                    if let data = try await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            viewModel.applyPickedImage(image)
                        }
                    } else {
                        await MainActor.run {
                            viewModel.alertKind = .imageLoadFailed
                        }
                    }
                } catch {
                    await MainActor.run {
                        viewModel.alertKind = .imageLoadFailed
                    }
                }
            }
        }
        .alert(item: $viewModel.alertKind) { alert in
            buildAlert(for: alert)
        }
    }

    private var imageCanvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DSColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DSColor.gridBorder, lineWidth: 2)
                )

            if let displayImage = viewModel.displayImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(8)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(DSColor.title)
                    Text(L10n.Image.uploadFromAlbum.localized)
                        .font(DSTypography.body)
                        .foregroundStyle(.secondary)
                }
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

    private func buildAlert(for alert: ImageSolveViewModel.AlertKind) -> Alert {
        switch alert {
        case .imageMissing:
            return Alert(
                title: Text(L10n.Image.imageMissingTitle.localized),
                message: Text(L10n.Image.imageMissingMessage.localized),
                dismissButton: .default(Text(L10n.Common.confirm.localized))
            )

        case .imageLoadFailed:
            return Alert(
                title: Text(L10n.Alert.routeUnavailableTitle.localized),
                message: Text(L10n.Alert.routeUnavailableMessage.localized),
                dismissButton: .default(Text(L10n.Common.confirm.localized))
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
                message: Text(L10n.Image.retryMessage.localized),
                primaryButton: .default(Text(L10n.Common.yes.localized)) {
                    viewModel.clearImage()
                },
                secondaryButton: .destructive(Text(L10n.Common.no.localized))
            )

        case .albumPermissionDenied:
            return Alert(
                title: Text(L10n.Settings.title.localized),
                message: Text(L10n.Image.albumPermissionDeniedMessage.localized),
                primaryButton: .default(Text(L10n.Common.confirm.localized)) {
                    viewModel.openSettings()
                },
                secondaryButton: .cancel(Text(L10n.Common.cancel.localized))
            )
        }
    }
}
