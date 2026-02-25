import SwiftUI

struct DSAlertModel: Identifiable {
    let id = UUID()
    let title: L10nToken
    let message: L10nToken
    let buttonText: L10nToken
}

extension View {
    func dsAlert(model: Binding<DSAlertModel?>) -> some View {
        alert(
            model.wrappedValue?.title.localized ?? "",
            isPresented: Binding(
                get: { model.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented {
                        model.wrappedValue = nil
                    }
                }
            ),
            presenting: model.wrappedValue
        ) { payload in
            Button(payload.buttonText.localized, role: .cancel) {
                model.wrappedValue = nil
            }
        } message: { payload in
            Text(payload.message.localized)
        }
    }
}
