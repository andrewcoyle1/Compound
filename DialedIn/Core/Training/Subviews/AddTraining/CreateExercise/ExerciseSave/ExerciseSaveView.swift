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
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .safeAreaInset(edge: .bottom) {
            // A "Create & Add" button sat above this one with an empty action. "Add" means adding the
            // new exercise to whatever the user was building, but `showCreateExerciseView()` takes no
            // delegate in any of its five router protocols, so four of its five entry points have
            // nothing to add to. Wiring it means threading a callback from ExerciseListBuilder through
            // CreateExercise to here — the same prefill plumbing ExerciseSettings' "Edit Duplicate"
            // needs, noted there too.
            CallToActionButton {
                presenter.onCreatePressed(delegate: delegate)
            } label: {
                Text("Create")
            }
            .accessibilityIdentifier("ExerciseSave.create")
            .disabled(presenter.isSaving)
            .padding(.bottom)
        }
    }

    private var definitionSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                Text("Exercise Name: ")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.exerciseName)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Trackable Metric: ")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.trackableMetricString)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Type: ")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.type?.name ?? "None")
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Laterality: ")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.laterality?.name ?? "None")
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("Definition")
                Spacer()
                Text("Final")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var targetMusclesSection: some View {
        let muscles = Array(delegate.targetMuscles).sorted { $0.key.name < $1.key.name }
        return Section {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(muscles, id: \.key) { muscle, targetType in
                        Text("\(muscle.name): \(targetType == .primary ? String(localized: "Primary") : String(localized: "Secondary"))")
                    }
                }
            }
            .scrollIndicators(.hidden)
        } header: {
            HStack {
                Text("Target Muscles")
                Spacer()
                Text("Final")
                    .font(.caption)
            }
        }
    }

    private var rangeOfMotionSection: some View {
        HStack {
            Text("Range of Motion")
            Spacer()
            HStack {
                ForEach(1...5) { value in
                    Capsule()
                        .fill(value <= delegate.rangeOfMotion ? Color.accentColor : Color.secondary.opacity(0.2))
                }
            }
            .frame(maxWidth: 200)
        }
    }

    private var stabilitySection: some View {
        HStack {
            Text("Stability")
            Spacer()
            HStack {
                ForEach(1...5) { value in
                    Capsule()
                        .fill(value <= delegate.stability ? Color.accentColor : Color.secondary.opacity(0.2))
                }
            }
            .frame(maxWidth: 200)
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
                        HStack {
                            Text("Resistance:")
                                .foregroundStyle(.secondary)
                            Text(equipment.equipmentId)
                        }
                    }
                    ForEach(variation.supportEquipment, id: \.self) { equipment in
                        HStack {
                            Text("Support:")
                                .foregroundStyle(.secondary)
                            Text(equipment.equipmentId)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Variation \(index + 1)")
                    Spacer()
                    Text("Final")
                        .font(.caption)
                }
            }
        }
    }

    private var detailsSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                Text("Body Weight Contribution: ")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(delegate.bodyweightContribution)%")
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Alternative Names: ")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.alternativeNamesConcatenated)
                    .lineLimit(2)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Description: ")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.exerciseDescription)
                    .lineLimit(2)

            }

        } header: {
            Text("Details")
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
