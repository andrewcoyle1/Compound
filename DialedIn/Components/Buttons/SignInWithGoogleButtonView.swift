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
        HStack(spacing: 4) {
            Spacer()
            ZStack {
                Image(resolvedStyle == .light ? "GoogleLogoLight" : "GoogleLogoDark")
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .clipShape(Rectangle().inset(by: 7.5))
            }
            .frame(width: 20, height: 20)
            Text(scheme.description)
                .foregroundStyle(resolvedStyle.accentColour)
                .fontWeight(.medium)
                .font(.title3)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 50)
        .background(resolvedStyle.backgroundColour)
        .cornerRadius(25)
        .frame(maxWidth: .infinity)
        .shadow(color: resolvedStyle.accentColour, radius: 1)
        .anyButton(.press) {
            action()
        }
        .frame(height: height)
        .frame(maxWidth: 408)
    }

    enum DisplayMode {
        case light
        case dark

        var backgroundColour: Color {
            switch self {
            case .light: return Color.white
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
