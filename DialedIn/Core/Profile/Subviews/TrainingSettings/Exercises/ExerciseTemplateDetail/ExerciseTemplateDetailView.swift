//
//  ExerciseDetailView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI

struct ExerciseModelDetailView: View {

    @State var presenter: ExerciseModelDetailPresenter

    var delegate: ExerciseModelDetailDelegate

    var body: some View {
        List {
            pickerSection
            switch presenter.section {
            case .description:
                aboutSection
            case .history:
                historySection
            case .charts:
                chartsSection
            case .records:
                recordsSection
            }
        }
        .navigationTitle(delegate.exerciseModel.name)
        .navigationSubtitle(presenter.performedSubtitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarContent
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
    }
    
    private var aboutSection: some View {
        Group {
            if let url = delegate.exerciseModel.imageURL {
                imageSection(url: url)
            }

            definitionSection

            if !delegate.exerciseModel.muscleGroups.isEmpty {
                targetMusclesSection
            }

            movementQualitySection

            equipmentVariationsSection

            detailsSection
            
            #if DEBUG
            metadataSection
            #endif
        }
    }
    
    @ViewBuilder
    private var historySection: some View {
        if presenter.stats.isEmpty {
            Section(header: Text("History")) {
                notLoggedYet
            }
        } else {
            Section(header: Text("History")) {
                ForEach(presenter.stats.mostRecentFirst) { performance in
                    ListRow(
                        title: performance.workoutName,
                        subtitle: historyDetail(performance),
                        accessory: .value(performance.date.formatted(date: .abbreviated, time: .omitted))
                    )
                }
            }
        }
    }

    private var notLoggedYet: some View {
        ContentUnavailableView {
            Label("Not Logged Yet", systemImage: Symbol.history)
        } description: {
            Text("You have not logged this exercise yet.")
        }
    }

    private func historyDetail(_ performance: ExerciseModelDetailStats.Performance) -> String {
        let sets = String(localized: "\(performance.workingSets) sets")
        let reps = Format.reps(performance.totalReps)
        let top = presenter.formattedWeight(performance.heaviestWeightKg)
        return String(localized: "\(String(describing: sets)) · \(String(describing: reps)) · top \(String(describing: top))")
    }
    
    private var pickerSection: some View {
        Section {
            Picker("Section", selection: $presenter.section) {
                Text("About").tag(CustomSection.description)
                Text("History").tag(CustomSection.history)
                Text("Charts").tag(CustomSection.charts)
                Text("Records").tag(CustomSection.records)
            }
            .pickerStyle(.segmented)
        }
        .listSectionSpacing(0)
        .removeListRowFormatting()
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }
        #if DEBUG || MOCK
        ToolbarItem(placement: .topBarLeading) {
            Button {
                presenter.onDevSettingsPressed()
            } label: {
                Image(systemName: Symbol.info)
            }
            .accessibilityLabel("Developer settings")
        }
        #endif
        if presenter.canDelete(exercise: delegate.exerciseModel) {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        presenter.showDeleteConfirmation(exercise: delegate.exerciseModel)
                    } label: {
                        Label("Delete Exercise", systemImage: Symbol.delete)
                    }
                } label: {
                    Image(systemName: Symbol.more)
                }
                .disabled(presenter.isDeleting)
                .accessibilityLabel("Exercise options")
            }
        }
    }
}

// MARK: - Sections (extracted for type_body_length)
private extension ExerciseModelDetailView {
    var chartsSection: some View {
        Group {
            weightProgressChart
            repsProgressChart
        }
    }

    @ViewBuilder
    var weightProgressChart: some View {
        Section(header: Text("Top Set")) {
            if presenter.stats.isEmpty {
                notLoggedYet
            } else {
                LineChart(data: presenter.weightSeries, configuration: presenter.weightChartConfiguration)
            }
        }
    }

    @ViewBuilder
    var repsProgressChart: some View {
        Section(header: Text("Reps Per Session")) {
            if presenter.stats.isEmpty {
                notLoggedYet
            } else {
                BarChart(data: presenter.repsSeries, configuration: presenter.repsChartConfiguration)
            }
        }
    }

    var recordsSection: some View {
        Group {
            personalBestSubSection
            recentRecordsSubSection
            allTimeStatsSubSection
        }
    }

    @ViewBuilder
    var personalBestSubSection: some View {
        Section {
            if let achieved = presenter.stats.heaviestSetDate, presenter.stats.heaviestSetKg > 0 {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("\(presenter.formattedWeight(presenter.stats.heaviestSetKg)) × \(Format.reps(presenter.stats.repsAtHeaviestSet))")
                            .font(.metric)
                        Label {
                            Text("Achieved on \(achieved.formatted(date: .abbreviated, time: .omitted))")
                        } icon: {
                            Image(systemName: Symbol.personalRecord)
                                .foregroundStyle(.personalRecord)
                        }
                        .font(.label)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Stat(value: presenter.formattedWeight(presenter.stats.bestOneRMKg), label: String(localized: "1RM"), alignment: .trailing)
                }
            } else {
                Text("No working sets logged yet.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Personal Best")
        }
    }

    /// The sessions where the estimated 1-RM beat everything before it — the points at which this
    /// exercise actually moved forward.
    @ViewBuilder
    var recentRecordsSubSection: some View {
        Section {
            let records = presenter.oneRMRecords
            if records.isEmpty {
                Text("No records yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records) { record in
                    ListRow(
                        title: record.date.formatted(date: .abbreviated, time: .omitted),
                        accessory: .value(presenter.formattedWeight(record.bestOneRMKg))
                    )
                }
            }
        } header: {
            Text("Recent Records")
        }
    }

    var allTimeStatsSubSection: some View {
        Section {
            HStack(alignment: .top, spacing: Spacing.xl) {
                Stat(value: presenter.stats.totalSets.formatted(), label: String(localized: "Total Sets"))
                Stat(value: presenter.stats.totalReps.formatted(), label: String(localized: "Total Reps"))
                Stat(value: presenter.formattedVolume(presenter.stats.totalVolumeKg), label: String(localized: "Total Volume"))
            }
            .padding(.vertical, Spacing.s)
        } header: {
            Text("All-Time Stats")
        }
    }

    var definitionSection: some View {
        Section {
            ListRow(title: String(localized: "Exercise Name"), accessory: .value(delegate.exerciseModel.name))
            ListRow(title: String(localized: "Trackable Metrics"), accessory: .value(trackableMetricString))
            ListRow(title: String(localized: "Type"), accessory: .value(delegate.exerciseModel.type?.name ?? String(localized: "None")))
            ListRow(title: String(localized: "Laterality"), accessory: .value(delegate.exerciseModel.laterality?.name ?? String(localized: "None")))
            ListRow(title: String(localized: "Bodyweight"), accessory: .value(delegate.exerciseModel.isBodyweight ? String(localized: "Yes") : String(localized: "No")))
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("Definition")
                Spacer()
                Text("Template")
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var targetMusclesSection: some View {
        let muscles = Array(delegate.exerciseModel.muscleGroups).sorted { $0.key.name < $1.key.name }
        return Section {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(muscles, id: \.key) { muscle, isSecondary in
                        Text("\(muscle.name): \(isSecondary == .secondary ? String(localized: "Secondary") : String(localized: "Primary"))")
                    }
                }
            }
            .scrollIndicators(.hidden)
        } header: {
            HStack {
                Text("Target Muscles")
                Spacer()
                Text("Template")
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var movementQualitySection: some View {
        Section {
            rangeOfMotionRow
            stabilityRow
        } header: {
            Text("Movement Quality")
        }
    }

    var rangeOfMotionRow: some View {
        HStack {
            Text("Range of Motion")
            Spacer()
            ratingBar(delegate.exerciseModel.rangeOfMotion)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Range of Motion"))
        .accessibilityValue(Text("\(delegate.exerciseModel.rangeOfMotion) of 5"))
    }

    var stabilityRow: some View {
        HStack {
            Text("Stability")
            Spacer()
            ratingBar(delegate.exerciseModel.stability)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Stability"))
        .accessibilityValue(Text("\(delegate.exerciseModel.stability) of 5"))
    }

    func ratingBar(_ rating: Int) -> some View {
        HStack {
            ForEach(1...5, id: \.self) { value in
                Capsule()
                    .fill(value <= rating ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
            }
        }
        .frame(maxWidth: 200)
    }

    var equipmentVariationsSection: some View {
        let variations = delegate.exerciseModel.equipmentVariations
        return Group {
            if variations.isEmpty {
                Section {
                    Text("None")
                        .foregroundStyle(.secondary)
                } header: {
                    HStack {
                        Text("Equipment")
                        Spacer()
                        Text("Template")
                            .font(.label)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(Array(variations.enumerated()), id: \.element.id) { index, variation in
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
                            Text("Template")
                                .font(.label)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    var detailsSection: some View {
        Section {
            ListRow(title: String(localized: "Body Weight Contribution"), accessory: .value(Format.percent(Double(delegate.exerciseModel.bodyWeightContribution) / 100)))
            ListRow(title: String(localized: "Alternative Names"), accessory: .value(alternateNamesConcatenated))
            ListRow(title: String(localized: "Description"), accessory: .value(delegate.exerciseModel.description ?? String(localized: "None")))
        } header: {
            Text("Details")
        }
    }

    var metadataSection: some View {
        Section {
            ListRow(title: String(localized: "Exercise ID"), accessory: .value(delegate.exerciseModel.id))
            if !delegate.exerciseModel.authorId.isEmpty {
                ListRow(title: String(localized: "Author ID"), accessory: .value(delegate.exerciseModel.authorId))
            }
            ListRow(title: String(localized: "System Exercise"), accessory: .value(delegate.exerciseModel.isSystemExercise ? String(localized: "Yes") : String(localized: "No")))
            ListRow(title: String(localized: "Date Created"), accessory: .value(delegate.exerciseModel.dateCreated.formatted(date: .abbreviated, time: .omitted)))
            ListRow(title: String(localized: "Date Modified"), accessory: .value(delegate.exerciseModel.dateModified.formatted(date: .abbreviated, time: .omitted)))
            ListRow(title: String(localized: "Click Count"), accessory: .value("\(delegate.exerciseModel.clickCount ?? 0)"))
            ListRow(title: String(localized: "Bookmark Count"), accessory: .value("\(delegate.exerciseModel.bookmarkCount ?? 0)"))
            ListRow(title: String(localized: "Favourite Count"), accessory: .value("\(delegate.exerciseModel.favouriteCount ?? 0)"))
            if let imageURL = delegate.exerciseModel.imageURL, !imageURL.isEmpty {
                ListRow(title: String(localized: "Image URL"), accessory: .value(imageURL))
            }
        } header: {
            Text("Metadata")
        }
    }

    func imageSection(url: String) -> some View {
        Section {
            if url.starts(with: "http://") || url.starts(with: "https://") {
                ImageLoaderView(urlString: url, resizingMode: .fit)
                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 250)
            } else {
                Image(url)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 250)
            }
        }
        .removeListRowFormatting()
    }

    func descriptionSection(description: String) -> some View {
        Section(header: Text("Description")) {
            Text(description)
                .font(.body)
        }
    }

    var trackableMetricString: String {
        let names = delegate.exerciseModel.trackableMetrics.map { $0.name }
        return names.isEmpty ? String(localized: "None") : names.joined(separator: " × ")
    }

    var alternateNamesConcatenated: String {
        delegate.exerciseModel.alternateNames.joined(separator: ", ")
    }
}

extension CoreBuilder {
    func exerciseModelDetailView(router: AnyRouter, delegate: ExerciseModelDetailDelegate) -> some View {
        ExerciseModelDetailView(
            presenter: ExerciseModelDetailPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showExerciseModelDetailView(delegate: ExerciseModelDetailDelegate) {
        router.showScreen(.sheet) { router in
            builder.exerciseModelDetailView(router: router, delegate: delegate)
        }
    }
}

#Preview("About Section") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.exerciseModelDetailView(
            router: router,
            delegate: ExerciseModelDetailDelegate(
                exerciseModel: ExerciseModel.mocks[0]
            )
        )
    }
    
}
