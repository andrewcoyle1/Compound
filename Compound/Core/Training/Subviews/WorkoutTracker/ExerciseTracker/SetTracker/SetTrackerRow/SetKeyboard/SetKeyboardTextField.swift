//
//  SetKeyboardTextField.swift
//  Compound
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
    private var inputView: SetKeyboardInputView?

    /// The hosting view sizes to the SwiftUI content, so the keyboard grows when the plate strip
    /// or effort row appears. It sits inside a self-sizing `UIInputView`, which is what lets the
    /// keys play the system keyboard click.
    func view(for presenter: SetKeyboardPresenter) -> UIView {
        if let inputView { return inputView }
        let host = UIHostingController(rootView: SetKeyboardView(presenter: presenter))
        host.sizingOptions = .intrinsicContentSize
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false

        let container = SetKeyboardInputView(frame: .zero, inputViewStyle: .default)
        container.allowsSelfSizing = true
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: container.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        hostingController = host
        inputView = container
        return container
    }
}

/// `UIDevice.playInputClick()` only sounds from an input view that asks for clicks.
final class SetKeyboardInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

struct SetKeyboardTextField: UIViewRepresentable {

    let field: SetKeyboardField
    let text: String
    let isActive: Bool
    let accessibilityLabel: String
    /// Drawn in the secondary colour: a set further down the table than the one being logged.
    var isMuted = false
    /// Shown greyed while the field is empty: last time's value, or "—". Never a value.
    var placeholder = Format.placeholder
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
        // The HIG's 11 pt floor: "102.5" in a 70 pt field used to shrink to 9 pt.
        textField.minimumFontSize = 11
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
        textField.placeholder = placeholder
        // Read as "empty" rather than the placeholder's dash; a hint says what it was last time.
        if text.isEmpty {
            textField.accessibilityValue = placeholder == Format.placeholder
                ? String(localized: "Empty")
                : String(localized: "Empty, last time \(placeholder)")
        } else {
            textField.accessibilityValue = nil
        }
        textField.textColor = isMuted ? .secondaryLabel : .label
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
