import SwiftUI

struct ExerciseSaveDelegate {

    let exerciseName: String
    let trackableMetricA: TrackableExerciseMetric
    let trackableMetricB: TrackableExerciseMetric?
    var type: ExerciseType?
    let laterality: Laterality?

    let targetMuscles: [Muscles: MuscleTargetType]

    let isBodyweight: Bool
    let equipmentVariations: [EquipmentVariation]

    let rangeOfMotion: Int
    let stability: Int

    let bodyweightContribution: Int
    let alternativeNames: [String]
    let exerciseDescription: String

    var eventParameters: [String: Any]? {
        nil
    }

    var trackableMetricString: String {
        if let metricB = self.trackableMetricB {
            return String(localized: "\(trackableMetricA.name) x \(metricB.name)")
        } else {
            return trackableMetricA.name
        }
    }

    var alternativeNamesConcatenated: String {
        alternativeNames.joined(separator: ", ")
    }
}

struct ExerciseSaveView: View {

    @State var presenter: ExerciseSavePresenter
    let delegate: ExerciseSaveDelegate

    var body: some View {
        List {
            definitionSection

            if !delegate.targetMuscles.isEmpty {
                targetMusclesSection
            }

            Section {
                rangeOfMotionSection
                stabilitySection
            }

            equipmentVariationsSection

            detailsSection
        }
        .navigationTitle("Save Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .bottomCTA {
            // A "Create & Add" button sat above this one with an empty action. "Add" means adding the
            // new exercise to whatever the user was building, but `showCreateExerciseView()` takes no
            // delegate in any of its five router protocols, so four of its five entry points have
            // nothing to add to. Wiring it means threading a callback from ExerciseListBuilder through
            // CreateExercise to here — the same prefill plumbing ExerciseSettings' "Edit Duplicate"
            // needs, noted there too.
            CallToActionButton(isLoading: presenter.isSaving) {
                presenter.onCreatePressed(delegate: delegate)
            } label: {
                Text("Create")
            }
            .accessibilityIdentifier("ExerciseSave.create")
            .disabled(presenter.isSaving)
        }
    }

    private var definitionSection: some View {
        Section {
            LabeledContent("Exercise Name", value: delegate.exerciseName)
            LabeledContent("Trackable Metric", value: delegate.trackableMetricString)
            LabeledContent("Type", value: delegate.type?.name ?? String(localized: "None"))
            LabeledContent("Laterality", value: delegate.laterality?.name ?? String(localized: "None"))
        } header: {
            Text("Definition")
        }
    }

    private var targetMusclesSection: some View {
        let muscles = Array(delegate.targetMuscles).sorted { $0.key.name < $1.key.name }
        return Section {
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.xs) {
                    ForEach(muscles, id: \.key) { muscle, targetType in
                        MuscleChip(muscle: muscle, target: targetType)
                    }
                }
            }
            .scrollIndicators(.hidden)
        } header: {
            Text("Target Muscles")
        }
    }

    private var rangeOfMotionSection: some View {
        LabeledContent("Range of Motion") {
            RatingBar(value: delegate.rangeOfMotion)
        }
    }

    private var stabilitySection: some View {
        LabeledContent("Stability") {
            RatingBar(value: delegate.stability)
        }
    }

    private var equipmentVariationsSection: some View {
        ForEach(Array(delegate.equipmentVariations.enumerated()), id: \.element.id) { index, variation in
            Section {
                if variation.resistanceEquipment.isEmpty && variation.supportEquipment.isEmpty {
                    Text("No equipment selected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(variation.resistanceEquipment, id: \.self) { equipment in
                        LabeledContent("Resistance", value: presenter.equipmentName(for: equipment))
                    }
                    ForEach(variation.supportEquipment, id: \.self) { equipment in
                        LabeledContent("Support", value: presenter.equipmentName(for: equipment))
                    }
                }
            } header: {
                Text("Variation \(index + 1)")
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Body Weight Contribution", value: Format.percent(Double(delegate.bodyweightContribution) / 100))
            LabeledContent("Alternative Names", value: delegate.alternativeNamesConcatenated)
            LabeledContent("Description", value: delegate.exerciseDescription)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = ExerciseSaveDelegate(
        exerciseName: "Bench Press",
        trackableMetricA: .reps,
        trackableMetricB: .weight,
        type: .compoundUpper,
        laterality: .bilateral,
        targetMuscles: [
            .chest: .primary,
            .frontDelts: .secondary,
            .triceps: .secondary
        ],
        isBodyweight: false,
        equipmentVariations: [],
        rangeOfMotion: 4,
        stability: 5,
        bodyweightContribution: 75,
        alternativeNames: [],
        exerciseDescription: ""
    )

    return RouterView { router in
        builder.exerciseSaveView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func exerciseSaveView(router: AnyRouter, delegate: ExerciseSaveDelegate) -> some View {
        ExerciseSaveView(
            presenter: ExerciseSavePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showExerciseSaveView(delegate: ExerciseSaveDelegate) {
        router.showScreen(.push) { router in
            builder.exerciseSaveView(router: router, delegate: delegate)
        }
    }
    
}

extension ExerciseModel {
    
    init(from delegate: ExerciseSaveDelegate, authorId: String) {
        self.id = UUID().uuidString
        self.authorId = authorId
        self.name = delegate.exerciseName
        self.description = delegate.exerciseDescription
        self.imageURL = nil
        self.trackableMetrics = [delegate.trackableMetricA, delegate.trackableMetricB].compactMap { $0 }
        self.type = delegate.type
        self.laterality = delegate.laterality
        self.muscleGroups = delegate.targetMuscles
        self.isBodyweight = delegate.isBodyweight
        self.equipmentVariations = delegate.equipmentVariations
        self.rangeOfMotion = delegate.rangeOfMotion
        self.stability = delegate.stability
        self.bodyWeightContribution = delegate.bodyweightContribution
        self.alternateNames = delegate.alternativeNames
        self.isSystemExercise = false
        self.dateCreated = .now
        self.dateModified = .now
        self.clickCount = 0
        self.bookmarkCount = 0
        self.favouriteCount = 0
    }

}
