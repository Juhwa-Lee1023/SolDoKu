import SwiftUI

struct DSPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSTypography.primaryButton)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(DSColor.primaryButtonForeground)
            .background(DSColor.primaryButton)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
