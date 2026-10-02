//
//  SignInWithAppleButtonView.swift
//  Compound
//
//  Created by Andrew Coyle on 10/9/24.
//
import SwiftUI
import AuthenticationServices

public enum AppleButtonStyle {
    case white
    case black
    case whiteOutline
    
    var asASAuth: ASAuthorizationAppleIDButton.Style {
        switch self {
        case .white:
            return .white
        case .black:
            return .black
        case .whiteOutline:
            return .whiteOutline
        }
    }
}

public enum AppleButtonType {
    case continueType
    case signIn
    case signUp
    
    var accessibilityLabel: Text {
        switch self {
        case .continueType: return Text("Continue with Apple")
        case .signIn: return Text("Sign in with Apple")
        case .signUp: return Text("Sign up with Apple")
        }
    }

    var asASAuth: ASAuthorizationAppleIDButton.ButtonType {
        switch self {
        case .continueType:
            return .continue
        case .signIn:
            return .signIn
        case .signUp:
            return .signUp
        }
    }
}
public struct SignInWithAppleButtonView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    public let type: AppleButtonType
    public var preferredStyle: AppleButtonStyle?
    public let cornerRadius: CGFloat
    public let height: CGFloat
    public let action: () -> Void

    private var resolvedStyle: AppleButtonStyle {
        if let preferredStyle { return preferredStyle }
        return colorScheme == .dark ? .white : .black
    }

    public init(
        
        type: AppleButtonType = .continueType,
        style: AppleButtonStyle? = nil,
        cornerRadius: CGFloat = 28,
        height: CGFloat = 56,
        action: @escaping () -> Void = {}
    ) {
        self.type = type
        self.preferredStyle = style
        self.cornerRadius = cornerRadius
        self.height = height
        self.action = action
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.001)
            SignInWithAppleButtonViewRepresentable(type: type.asASAuth, style: resolvedStyle.asASAuth, cornerRadius: cornerRadius)
                .disabled(true)
        }
        .frame(height: height)
        .anyButton(.press) {
            action()
        }
        // The system button is drawn disabled under a tap target, so VoiceOver found no name.
        .accessibilityLabel(type.accessibilityLabel)
        .frame(maxWidth: 408)
    }
}

private struct SignInWithAppleButtonViewRepresentable: UIViewRepresentable {
    let type: ASAuthorizationAppleIDButton.ButtonType
    let style: ASAuthorizationAppleIDButton.Style
    let cornerRadius: CGFloat

    func makeUIView(context: Context) -> UIView {
        // Create a container view
        let containerView = UIView()
        
        // Create the button
        let button = ASAuthorizationAppleIDButton(type: type, style: style)
        button.cornerRadius = cornerRadius
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add button to container
        containerView.addSubview(button)
        
        // Pin button to all edges of container
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: containerView.topAnchor),
            button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Store button reference and current properties in coordinator
        context.coordinator.currentButton = button
        context.coordinator.currentStyle = style
        context.coordinator.currentType = type
        context.coordinator.currentCornerRadius = cornerRadius
        
        return containerView
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        // ASAuthorizationAppleIDButton doesn't support changing style after creation,
        // so we need to replace it if the style or type has changed
        
        if context.coordinator.currentStyle != style || context.coordinator.currentType != type {
            // Remove old button
            context.coordinator.currentButton?.removeFromSuperview()
            
            // Create new button with updated style
            let newButton = ASAuthorizationAppleIDButton(type: type, style: style)
            newButton.cornerRadius = cornerRadius
            newButton.translatesAutoresizingMaskIntoConstraints = false
            
            // Add new button to container
            uiView.addSubview(newButton)
            
            // Pin button to all edges of container
            NSLayoutConstraint.activate([
                newButton.topAnchor.constraint(equalTo: uiView.topAnchor),
                newButton.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
                newButton.trailingAnchor.constraint(equalTo: uiView.trailingAnchor),
                newButton.bottomAnchor.constraint(equalTo: uiView.bottomAnchor)
            ])
            
            // Update coordinator
            context.coordinator.currentButton = newButton
            context.coordinator.currentStyle = style
            context.coordinator.currentType = type
            context.coordinator.currentCornerRadius = cornerRadius
        } else if context.coordinator.currentCornerRadius != cornerRadius {
            // Just update corner radius if only that changed
            context.coordinator.currentButton?.cornerRadius = cornerRadius
            context.coordinator.currentCornerRadius = cornerRadius
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var currentButton: ASAuthorizationAppleIDButton?
        var currentStyle: ASAuthorizationAppleIDButton.Style = .black
        var currentType: ASAuthorizationAppleIDButton.ButtonType = .signIn
        var currentCornerRadius: CGFloat = 10
    }
}

#Preview("SignInWithAppleButtonView") {
    VStack(spacing: 4) {
        SignInWithAppleButtonView(
            type: .signUp,
            style: .black,
            cornerRadius: 10
        )
        .frame(height: 50)
    }
    .padding(40)
}
