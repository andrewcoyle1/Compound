//
//  OnboardingStepScaffold.swift
//  Compound
//

import SwiftUI

/// The shared shape of an onboarding step: a `List` under a large title, an optional progress
/// bar at the top of the list, the developer-settings toolbar in debug and mock builds, and a
/// primary call to action (plus an optional plain secondary button) through `.bottomCTA`.
///
/// The bar scrolls with the list rather than sitting in a top `safeAreaBar`: a top bar brings the
/// scroll-edge effect with it, which blurs the large title above it into illegibility.
///
/// Progress is a thin bar rather than a "Step x of y" subtitle: the
/// account-setup sub-screens share one `OnboardingStep`, so a step count would not advance
/// between them, while a fraction reads the same either way.
///
/// ```swift
/// OnboardingStepScaffold(
///     title: "About You",
///     subtitle: "Select your gender",
///     progress: OnboardingStep.completeAccountSetup.progress,
///     primary: .init(title: "Continue", isEnabled: presenter.canSubmit) { presenter.onContinuePressed() },
///     onDevSettingsPressed: presenter.onDevSettingsPressed
/// ) {
///     Section { … }
/// }
/// ```
struct OnboardingStepScaffold<Content: View>: View {

    struct Primary {
        var title: LocalizedStringKey
        var isEnabled: Bool = true
        var isLoading: Bool = false
        /// The UI tests' handle on the button, such as `Continue`.
        var identifier: String?
        var action: () -> Void
    }

    struct Secondary {
        var title: LocalizedStringKey
        var identifier: String?
        var action: () -> Void
    }

    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var progress: Double?
    let primary: Primary
    var secondary: Secondary?
    var onDevSettingsPressed: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        progress: Double? = nil,
        primary: Primary,
        secondary: Secondary? = nil,
        onDevSettingsPressed: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.progress = progress
        self.primary = primary
        self.secondary = secondary
        self.onDevSettingsPressed = onDevSettingsPressed
        self.content = content
    }

    var body: some View {
        List {
            if progress != nil || subtitle != nil {
                Section {
                } header: {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        if let progress {
                            ProgressView(value: progress)
                                .accessibilityLabel("Onboarding progress")
                        }
                        if let subtitle {
                            Text(subtitle)
                        }
                    }
                }
                .listSectionSpacing(0)
            }
            content()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        #if DEBUG || MOCK
        .toolbar {
            if let onDevSettingsPressed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onDevSettingsPressed) {
                        Image(systemName: Symbol.info)
                    }
                    .accessibilityLabel("Developer settings")
                }
            }
        }
        #endif
        .bottomCTA {
            CallToActionButton(isLoading: primary.isLoading, action: primary.action) {
                Text(primary.title)
            }
            .disabled(!primary.isEnabled)
            .accessibilityIdentifier(primary.identifier ?? "")
            if let secondary {
                Button(action: secondary.action) {
                    // The 44 pt height in the layout, so the hit area stops short of the button above.
                    Text(secondary.title)
                        .frame(maxWidth: .infinity, minHeight: ControlSize.row)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .accessibilityIdentifier(secondary.identifier ?? "")
            }
        }
    }
}

extension OnboardingStep {
    /// How far through onboarding this step is, in `0...1`, for `OnboardingStepScaffold`'s
    /// progress bar. Derived from `orderIndex`; `.complete` is the last step and reads 1.
    var progress: Double {
        Double(orderIndex + 1) / Double(OnboardingStep.complete.orderIndex + 1)
    }
}

// MARK: - Preview

private struct OnboardingOptionsPreview: View {
    @State private var selection = "Male"

    private func onDevSettingsPressed() { }

    var body: some View {
        OnboardingStepScaffold(
            title: "About You",
            subtitle: "Select your gender",
            progress: OnboardingStep.completeAccountSetup.progress,
            primary: .init(title: "Continue") { },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            Section {
                ForEach(["Male", "Female"], id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        HStack {
                            Text(option).font(.rowTitle)
                            Spacer()
                            if selection == option {
                                Image(systemName: Symbol.success)
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                }
            }
        }
    }
}

private struct OnboardingPickerPreview: View {
    @State private var centimeters = 175

    var body: some View {
        OnboardingStepScaffold(
            title: "How tall are you?",
            progress: OnboardingStep.completeAccountSetup.progress,
            primary: .init(title: "Continue", isLoading: true) { }
        ) {
            Section("Metric") {
                Picker("Centimeters", selection: $centimeters) {
                    ForEach((100...250).reversed(), id: \.self) { value in
                        Text("\(value) cm").tag(value)
                    }
                }
                .pickerStyle(.wheel)
            }
        }
    }
}

private struct OnboardingTwoButtonPreview: View {
    var body: some View {
        OnboardingStepScaffold(
            title: "Connect with Strava",
            subtitle: "Upload every workout",
            progress: OnboardingStep.customiseProgram.progress,
            primary: .init(title: "Connect Strava") { },
            secondary: .init(title: "Skip for now") { }
        ) {
            Section {
                Label("Workout reminders", systemImage: Symbol.workout)
                Label("Meal logging nudges", systemImage: Symbol.meal)
            }
        }
    }
}

#Preview("Options, light") {
    NavigationStack { OnboardingOptionsPreview() }.preferredColorScheme(.light)
}

#Preview("Options, dark") {
    NavigationStack { OnboardingOptionsPreview() }.preferredColorScheme(.dark)
}

#Preview("Picker, loading") {
    NavigationStack { OnboardingPickerPreview() }
}

#Preview("Two buttons, accessibility size") {
    NavigationStack { OnboardingTwoButtonPreview() }.dynamicTypeSize(.accessibility3)
}
