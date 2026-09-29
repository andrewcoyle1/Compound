//
//  AppleHealthFillSection.swift
//  DialedIn
//
//  "Fill from Apple Health" on the date of birth, sex, height and weight steps (decision 11e).
//  Tapping asks for that one type only, at that moment, so it is an in-context request rather
//  than an onboarding permission screen. Manual entry below it is untouched either way.
//

import SwiftUI

enum AppleHealthFillState: Equatable {
    case idle
    case loading
    case filled
    /// Nothing stored, or read access refused: HealthKit does not say which.
    case notFound
}

struct AppleHealthFillSection: View {
    let state: AppleHealthFillState
    let action: () -> Void

    var body: some View {
        Section {
            Button(action: action) {
                HStack {
                    Label("Fill from Apple Health", systemImage: "heart.text.square")
                    Spacer()
                    if state == .loading {
                        ProgressView()
                    }
                }
            }
            .disabled(state == .loading)
            .accessibilityIdentifier("FillFromAppleHealth")

            switch state {
            case .filled:
                InlineMessage(.info, "Filled from Apple Health. Check it before you continue.")
            case .notFound:
                InlineMessage(.info, "Nothing found in Apple Health, or access is off. Enter it below.")
            case .idle, .loading:
                EmptyView()
            }
        }
    }
}

#Preview("States") {
    List {
        AppleHealthFillSection(state: .idle) { }
        AppleHealthFillSection(state: .loading) { }
        AppleHealthFillSection(state: .filled) { }
        AppleHealthFillSection(state: .notFound) { }
    }
}
