//
//  SignInWithGoogleButton.swift
//  DialedIn
//
//  Created by Andrew Coyle on 03/10/2025.
//

import SwiftUI

struct SignInWithGoogleButtonView: View {

    @Environment(\.colorScheme) private var colorScheme

    let style: DisplayMode?
    let scheme: DisplayScheme
    let action: () -> Void
    let height: CGFloat
    
    private var resolvedStyle: DisplayMode {
        if let style { return style }
        return colorScheme == .dark ? .dark : .light
    }
    
    init(
        style: DisplayMode? = nil,
        scheme: DisplayScheme = .continueWithGoogle,
        action: @escaping () -> Void = {},
        height: CGFloat = 56
    ) {
        self.style = style
        self.scheme = scheme
        self.action = action
        self.height = height
    }
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Spacer()
            ZStack {
                Image(resolvedStyle == .light ? "GoogleLogoLight" : "GoogleLogoDark")
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .clipShape(Rectangle().inset(by: 7.5))
            }
            .frame(width: 20, height: 20)
            .accessibilityHidden(true)
            Text(scheme.description)
                .foregroundStyle(resolvedStyle.accentColour)
                .fontWeight(.medium)
                .font(.title3)
            Spacer()
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
        // The same size and shape as the Apple button beside it: `height` tall (a minimum, so large
        // text grows it instead of clipping) and a capsule, which is what Apple's 28 pt radius on
        // a 56 pt button draws.
        .frame(maxWidth: .infinity, minHeight: height)
        .background(resolvedStyle.backgroundColour, in: .capsule)
        .overlay {
            Capsule().strokeBorder(.separator)
        }
        .anyButton(.press) {
            action()
        }
        .frame(maxWidth: 408)
    }

    enum DisplayMode {
        case light
        case dark

        var backgroundColour: Color {
            switch self {
            case .light: return Color.white
            // Google's branding guidelines fix this fill (#131314); it is not a design token.
            // swiftlint:disable:next no_rgb_color_literal
            case .dark: return Color(red: 19/255, green: 19/255, blue: 20/255)
            }
        }

        var accentColour: Color {
            switch self {
            case .light: return Color.black
            case .dark: return Color.white
            }
        }
    }

    enum DisplayScheme {
        case signUpWithGoogle
        case signInWithGoogle
        case continueWithGoogle

        var description: String {
            switch self {
            case .signInWithGoogle: return String(localized: "Sign In with Google")
            case .signUpWithGoogle: return String(localized: "Sign Up with Google")
            case .continueWithGoogle: return String(localized: "Continue with Google")
            }
        }
    }
}

#Preview("Light - Sign In") {
    ZStack {
        Color.white.ignoresSafeArea()
        SignInWithGoogleButtonView(style: .light, scheme: .signInWithGoogle) {

        }
    }
}

#Preview("Dark - Sign Up") {
    ZStack {
        Color.black.ignoresSafeArea()
        SignInWithGoogleButtonView(style: .dark, scheme: .signUpWithGoogle) {

        }
    }
}

#Preview("Dark - Continue") {
    ZStack {
        Color.black.ignoresSafeArea()
        SignInWithGoogleButtonView(style: .dark, scheme: .continueWithGoogle) {

        }
    }
}
