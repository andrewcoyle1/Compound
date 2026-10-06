import SwiftUI

struct FinalExerciseDetailsDelegate {
    let name: String
    let trackableMetricA: TrackableExerciseMetric
    let trackableMetricB: TrackableExerciseMetric?
    let exerciseType: ExerciseType?
    let laterality: Laterality?
    let targetMuscles: [Muscles: MuscleTargetType]

    let isBodyweight: Bool
    let equipmentVariations: [EquipmentVariation]

    var eventParameters: [String: Any]? {
        nil
    }
}

struct FinalExerciseDetailsView: View {
    
    @State var presenter: FinalExerciseDetailsPresenter
    let delegate: FinalExerciseDetailsDelegate

    var body: some View {
        Form {
            rangeOfMotionSection
                .listSectionMargins(.top, 0)
            stabilitySection

            bodyweightSection

            alternateNamesSection

            descriptionSection
        }
        .navigationTitle("Final Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .bottomCTA {
            CallToActionButton {
                presenter.onNextPressed(delegate: delegate)
            } label: {
                Text("Next")
            }
            .accessibilityIdentifier("FinalExerciseDetails.next")
            .disabled(!presenter.canContinue(delegate: delegate))
        }
    }

    private var rangeOfMotionSection: some View {
        ratingStepper(String(localized: "Range of Motion"), value: $presenter.rangeOfMotion)
    }

    private var stabilitySection: some View {
        ratingStepper(String(localized: "Stability"), value: $presenter.stability)
    }

    /// VoiceOver reads the rating as "3 of 5" through the stepper's value.
    private func ratingStepper(_ title: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 0...5) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(title)
                    .font(.rowTitle)
                RatingBar(value: value.wrappedValue)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityValue(String(localized: "\(value.wrappedValue) of 5"))
    }

    private var bodyweightSection: some View {
        Section {
            HStack {
                TextField("Body weight contribution, percent", value: $presenter.bodyweightContribution, format: .number, prompt: Text("0"))
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("FinalExerciseDetails.contribution")
                Text("%")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            if !presenter.isContributionInRange {
                InlineMessage(.error, "Enter a number from 0 to 100.")
            }
            if presenter.hasBodyweightConflict(delegate: delegate) {
                InlineMessage(.warning, "A bodyweight exercise cannot track a load. Go back and turn off Bodyweight Exercise, or track without weight.")
            }
        } header: {
            Text("Body Weight Contribution")
        } footer: {
            Text(presenter.contributionFooter(delegate: delegate))
        }
    }

    private var alternateNamesSection: some View {
        Section {
            TextField(text: Binding(get: { presenter.alternateNames }, set: { presenter.onAlternateNamesChanged($0) }), prompt: Text("Optionally add other names")) {
                Text("Alternate Names")
            }
            .lineLimit(2)
        } header: {
            HStack {
                Text("Alternate Names")
                Spacer()
                Text("\(presenter.alternateNames.count)/\(FinalExerciseDetailsPresenter.alternateNamesLimit)")
            }
        } footer: {
            Text("Separate names with a comma.")
        }
    }

    private var descriptionSection: some View {
        Section {
            TextField("Optionally describe the exercise", text: $presenter.exerciseDescription, axis: .vertical)
                .lineLimit(2...6)
                .accessibilityIdentifier("FinalExerciseDetails.description")
        } header: {
            Text("Description")
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = FinalExerciseDetailsDelegate(
        name: "Bench Press",
        trackableMetricA: .reps,
        trackableMetricB: .weight,
        exerciseType: .compoundUpper,
        laterality: .bilateral,
        targetMuscles: [.chest: .primary, .frontDelts: .secondary, .triceps: .secondary],
        isBodyweight: false,
        equipmentVariations: []
    )

    return RouterView { router in
        builder.finalExerciseDetailsView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func finalExerciseDetailsView(router: AnyRouter, delegate: FinalExerciseDetailsDelegate) -> some View {
        FinalExerciseDetailsView(
            presenter: FinalExerciseDetailsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                isBodyweight: delegate.isBodyweight
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showFinalExerciseDetailsView(delegate: FinalExerciseDetailsDelegate) {
        router.showScreen(.push) { router in
            builder.finalExerciseDetailsView(router: router, delegate: delegate)
        }
    }
    
}
