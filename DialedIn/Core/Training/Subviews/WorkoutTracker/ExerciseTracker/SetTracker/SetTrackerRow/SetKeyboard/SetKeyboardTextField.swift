//
//  SetKeyboardTextField.swift
//  DialedIn
//
//  A text field whose keyboard is `SetKeyboardView`. SwiftUI's `TextField` cannot replace the
//  system keyboard, and a UIKit `inputView` is the one way that also keeps hardware keyboards
//  typing into the field.
//

import SwiftUI
import UIKit

/// `STARTSCREEN_SET_KEYBOARD` opens the tracker with the first weight keyboard up.
@MainActor
enum SetKeyboardLaunch {
    static var isPending = ProcessInfo.processInfo.arguments.contains("STARTSCREEN_SET_KEYBOARD")
}

/// One keyboard per row, shared by its weight and reps fields so moving between them does not
/// dismiss and re-present it.
@MainActor
final class SetKeyboardInputHost {
    private var hostingController: UIHostingController<SetKeyboardView>?

    /// The hosting view is the input view itself and sizes to the SwiftUI content, so the
    /// keyboard grows when the plate strip or effort row appears.
    func view(for presenter: SetKeyboardPresenter) -> UIView {
        if let view = hostingController?.view { return view }
        let host = UIHostingController(rootView: SetKeyboardView(presenter: presenter))
        host.sizingOptions = .intrinsicContentSize
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController = host
        return host.view
    }
}

struct SetKeyboardTextField: UIViewRepresentable {

    let field: SetKeyboardField
    let text: String
    let isActive: Bool
    let accessibilityLabel: String
    let presenter: SetKeyboardPresenter
    let inputHost: SetKeyboardInputHost
    let onBegin: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.textAlignment = .center
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.adjustsFontSizeToFitWidth = true
        textField.minimumFontSize = 9
        textField.placeholder = "-"
        textField.inputView = inputHost.view(for: presenter)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        textField.isEnabled = context.environment.isEnabled
        if textField.text != text { textField.text = text }
        textField.accessibilityLabel = accessibilityLabel
        // Focus follows the presenter, so Next and Prev move it. Deferred: first responder
        // cannot change in the middle of a view update.
        if isActive != textField.isFirstResponder {
            DispatchQueue.main.async {
                if isActive { textField.becomeFirstResponder() } else if textField.isFirstResponder { textField.resignFirstResponder() }
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SetKeyboardTextField?

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent?.onBegin()
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            // Focus went somewhere the keyboard did not send it: another row, or away entirely.
            guard let parent, parent.presenter.activeField == parent.field else { return }
            parent.presenter.close()
        }

        /// Hardware keys go through the same path as the on-screen ones.
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard let presenter = parent?.presenter else { return false }
            if string.isEmpty {
                presenter.backspace()
            } else {
                string.forEach { presenter.type($0) }
            }
            return false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            guard let parent else { return false }
            if parent.field == .weight { parent.presenter.next() } else { parent.presenter.done() }
            return false
        }
    }
}
