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
                Text("You have not logged this exercise yet.")
                    .foregroundColor(.secondary)
            }
        } else {
            Section(header: Text("History")) {
                ForEach(presenter.stats.mostRecentFirst) { performance in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(performance.workoutName)
                                .font(.subheadline.weight(.medium))
                            Spacer(minLength: 0)
                            Text(performance.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(historyDetail(performance))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func historyDetail(_ performance: ExerciseModelDetailStats.Performance) -> String {
        let sets = "\(performance.workingSets) × sets"
        let reps = "\(performance.totalReps) reps"
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
        ToolbarItem(placement: .topBarLeading) {
            Button {
                presenter.onDismissPressed()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")
        }
        #if DEBUG || MOCK
        ToolbarItem(placement: .topBarLeading) {
            Button {
                presenter.onDevSettingsPressed()
            } label: {
                Image(systemName: "info")
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
                        Label("Delete Exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
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
                Text("You have not logged this exercise yet.")
                    .foregroundColor(.secondary)
            } else {
                LineChart(data: presenter.weightSeries, configuration: presenter.weightChartConfiguration)
            }
        }
    }

    @ViewBuilder
    var repsProgressChart: some View {
        Section(header: Text("Reps Per Session")) {
            if presenter.stats.isEmpty {
                Text("You have not logged this exercise yet.")
                    .foregroundColor(.secondary)
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
                HStack {
                    VStack {
                        Text("\(presenter.formattedWeight(presenter.stats.heaviestSetKg)) x \(presenter.stats.repsAtHeaviestSet) reps")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)
                            Text("Achieved on \(achieved.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    VStack {
                        Text("1RM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(presenter.formattedWeight(presenter.stats.bestOneRMKg))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
            } else {
                Text("No working sets logged yet.")
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
            } else {
                ForEach(records) { record in
                    HStack {
                        Text(record.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                        Spacer(minLength: 0)
                        Text(presenter.formattedWeight(record.bestOneRMKg))
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
        } header: {
            Text("Recent Records")
        }
    }

    var allTimeStatsSubSection: some View {
        Section {
            HStack(spacing: 24) {
                VStack {
                    Text("Total Sets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(presenter.stats.totalSets)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                VStack {
                    Text("Total Reps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(presenter.stats.totalReps)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                VStack {
                    Text("Total Volume")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(presenter.formattedVolume(presenter.stats.totalVolumeKg))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
        } header: {
            Text("All-Time Stats")
        }
        .padding(.vertical, 8)
    }

    var definitionSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                Text("Exercise Name")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.exerciseModel.name)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Trackable Metrics")
                    .fontWeight(.semibold)
                Spacer()
                Text(trackableMetricString)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Type")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.exerciseModel.type?.name ?? "None")
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Laterality")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.exerciseModel.laterality?.name ?? "None")
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Bodyweight")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.exerciseModel.isBodyweight ? String(localized: "Yes") : String(localized: "No"))
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("Definition")
                Spacer()
                Text("Template")
                    .font(.caption)
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
                    .font(.caption)
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
            HStack {
                ForEach(1...5, id: \.self) { value in
                    Capsule()
                        .fill(value <= delegate.exerciseModel.rangeOfMotion ? Color.accentColor : Color.secondary.opacity(0.2))
                }
            }
            .frame(maxWidth: 200)
        }
    }

    var stabilityRow: some View {
        HStack {
            Text("Stability")
            Spacer()
            HStack {
                ForEach(1...5, id: \.self) { value in
                    Capsule()
                        .fill(value <= delegate.exerciseModel.stability ? Color.accentColor : Color.secondary.opacity(0.2))
                }
            }
            .frame(maxWidth: 200)
        }
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
                            .font(.caption)
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
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    var detailsSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                Text("Body Weight Contribution")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(delegate.exerciseModel.bodyWeightContribution)%")
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Alternative Names")
                    .fontWeight(.semibold)
                Spacer()
                Text(alternateNamesConcatenated)
                    .foregroundStyle(alternateNamesConcatenated.isEmpty ? .secondary : .primary)
                    .lineLimit(2)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Description")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.exerciseModel.description ?? "None")
                    .foregroundStyle(delegate.exerciseModel.description == nil ? .secondary : .primary)
                    .lineLimit(3)
            }
        } header: {
            Text("Details")
        }
    }

    var metadataSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                Text("Exercise ID")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.exerciseModel.id)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            if !delegate.exerciseModel.authorId.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text("Author ID")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(delegate.exerciseModel.authorId)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text("System Exercise")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.exerciseModel.isSystemExercise ? String(localized: "Yes") : String(localized: "No"))
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Date Created")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.exerciseModel.dateCreated.formatted(date: .abbreviated, time: .omitted))
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Date Modified")
                    .fontWeight(.semibold)
                Spacer()
                Text(delegate.exerciseModel.dateModified.formatted(date: .abbreviated, time: .omitted))
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Click Count")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(delegate.exerciseModel.clickCount ?? 0)")
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Bookmark Count")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(delegate.exerciseModel.bookmarkCount ?? 0)")
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Favourite Count")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(delegate.exerciseModel.favouriteCount ?? 0)")
            }
            if let imageURL = delegate.exerciseModel.imageURL, !imageURL.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text("Image URL")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(imageURL)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
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
        return names.isEmpty ? "None" : names.joined(separator: " x ")
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
