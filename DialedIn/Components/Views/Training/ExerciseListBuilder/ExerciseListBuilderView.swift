import SwiftUI

struct ExerciseListBuilderDelegate {
    var onExerciseSelectionChanged: ((ExerciseModel) -> Void)?
    /// Optional list of exercises that should display as "selected" in the UI.
    /// If `nil`, no selection state is shown.
    var selectedExercises: [ExerciseModel]?
}

struct ExerciseListBuilderView: View {
    
    @State var presenter: ExerciseListBuilderPresenter
    
    let delegate: ExerciseListBuilderDelegate
    
    private func isExerciseSelected(_ exercise: ExerciseModel) -> Bool {
        delegate.selectedExercises?.contains(exercise) ?? false
    }
    
    var body: some View {
        List {
            if presenter.searchText.isEmpty {
                userExercisesSection
                systemExercisesSection
                // A filter can empty both sections, and a list with two bare headers and nothing
                // under them does not explain itself.
                if presenter.filters.isActive,
                   presenter.userExercises.isEmpty,
                   presenter.systemExercises.isEmpty {
                    noMatchesSection
                }
            } else {
                filteredExercisesSection
            }
        }
        .overlay {
            if !presenter.searchText.isEmpty && presenter.filteredExercises.isEmpty {
                ContentUnavailableView.search(text: presenter.searchText)
            }
        }
        .searchable(text: $presenter.searchText, placement: .toolbar, prompt: Text("Search exercises"))
        .scrollIndicators(.hidden)
        .toolbarVisibility(.hidden)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .safeAreaInset(edge: .top) {
            filterSection
        }
    }
    
    // MARK: - Filter bar

    /// Each chip is a `Menu` of inline toggles rather than a pushed picker screen: nine chips would
    /// otherwise mean nine screens, and a filter you set and unset repeatedly wants to stay put
    /// while you do it. A chip tints and counts itself when its dimension is narrowing the list.
    private var filterSection: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack {
                    resetChip

                    gymChip

                    multiSelectChip(
                        "Type",
                        systemImage: "signpost.right",
                        options: ExerciseType.allCases,
                        name: \.name,
                        selection: $presenter.filters.types
                    )

                    multiSelectChip(
                        "Laterality",
                        systemImage: "arrowshape.left.arrowshape.right",
                        options: Laterality.allCases,
                        name: \.name,
                        selection: $presenter.filters.lateralities
                    )

                    multiSelectChip(
                        "Resistance",
                        systemImage: "scalemass",
                        options: EquipmentKind.allCases,
                        name: \.sectionTitle,
                        selection: $presenter.filters.resistanceKinds
                    )

                    multiSelectChip(
                        "Support",
                        systemImage: "bed.double",
                        options: EquipmentKind.allCases,
                        name: \.sectionTitle,
                        selection: $presenter.filters.supportKinds
                    )

                    ratingChip(
                        "Range of Motion",
                        systemImage: "arrowshape.left.arrowshape.right",
                        minimum: $presenter.filters.minimumRangeOfMotion
                    )

                    ratingChip(
                        "Stability",
                        systemImage: "camera.metering.center.weighted.average",
                        minimum: $presenter.filters.minimumStability
                    )

                    libraryChip
                        .padding(.trailing)
                }
            }
        }
        .scrollIndicators(.hidden)
        // The reset chip used to carry the leading inset, and it is hidden until a filter is active.
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }

    /// Only offered when something is actually filtered — a reset that resets nothing reads as a
    /// broken button.
    @ViewBuilder
    private var resetChip: some View {
        if presenter.filters.isActive {
            Image(systemName: "arrow.counterclockwise")
                .padding(8)
                .glassEffect(.clear.interactive())
                .anyButton {
                    presenter.onResetFiltersPressed()
                }
                .accessibilityLabel("Clear filters")
        }
    }

    private var gymChip: some View {
        Menu {
            Picker("Gym", selection: $presenter.filters.gymProfileId) {
                Text("Any Equipment").tag(nil as String?)
                ForEach(presenter.gymProfiles) { profile in
                    Text(profile.name).tag(profile.id as String?)
                }
            }
        } label: {
            chipLabel(
                presenter.gymFilterLabel,
                systemImage: "building",
                isActive: presenter.filters.gymProfileId != nil
            )
        }
        .onChange(of: presenter.filters.gymProfileId) { _, _ in
            presenter.onFilterChanged("gym")
        }
    }

    private var libraryChip: some View {
        Menu {
            Picker("Library", selection: $presenter.filters.library) {
                ForEach(ExerciseFilters.LibraryScope.allCases) { scope in
                    Text(scope.name).tag(scope)
                }
            }
        } label: {
            chipLabel(
                presenter.filters.library == .all ? "Library" : presenter.filters.library.name,
                systemImage: "book.closed",
                isActive: presenter.filters.library != .all
            )
        }
        .onChange(of: presenter.filters.library) { _, _ in
            presenter.onFilterChanged("library")
        }
    }

    /// A chip over any `Hashable & Identifiable` option set, so Type, Laterality, Resistance and
    /// Support are one implementation instead of four near-copies.
    private func multiSelectChip<Option: Hashable & Identifiable>(
        _ title: String,
        systemImage: String,
        options: [Option],
        name: KeyPath<Option, String>,
        selection: Binding<Set<Option>>
    ) -> some View {
        Menu {
            ForEach(options) { option in
                Button {
                    if selection.wrappedValue.contains(option) {
                        selection.wrappedValue.remove(option)
                    } else {
                        selection.wrappedValue.insert(option)
                    }
                    presenter.onFilterChanged(title)
                } label: {
                    if selection.wrappedValue.contains(option) {
                        Label(option[keyPath: name], systemImage: "checkmark")
                    } else {
                        Text(option[keyPath: name])
                    }
                }
            }
        } label: {
            chipLabel(
                title,
                systemImage: systemImage,
                isActive: !selection.wrappedValue.isEmpty,
                count: selection.wrappedValue.count
            )
        }
    }

    /// Range of motion and stability are 0...5 ratings, so the chip offers a floor rather than an
    /// exact value.
    private func ratingChip(
        _ title: String,
        systemImage: String,
        minimum: Binding<Int?>
    ) -> some View {
        Menu {
            Picker(title, selection: minimum) {
                Text("Any").tag(nil as Int?)
                ForEach(1...5, id: \.self) { rating in
                    Text("\(rating)+").tag(rating as Int?)
                }
            }
        } label: {
            chipLabel(
                minimum.wrappedValue.map { "\(title) \($0)+" } ?? title,
                systemImage: systemImage,
                isActive: minimum.wrappedValue != nil
            )
        }
        .onChange(of: minimum.wrappedValue) { _, _ in
            presenter.onFilterChanged(title)
        }
    }

    private func chipLabel(
        _ title: String,
        systemImage: String,
        isActive: Bool,
        count: Int = 0
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(title)
            if count > 1 {
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .background(.tint.opacity(0.25), in: .capsule)
            }
        }
        .lineLimit(1)
        .padding(8)
        .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        .glassEffect(.clear.interactive())
    }

    private var userExercisesSection: some View {
        Section {
            if !presenter.userExercises.isEmpty {
                ForEach(presenter.userExercises) { exercise in
                    CustomListCellView(
                        imageName: exercise.imageURL,
                        title: exercise.name,
                        subtitle: exercise.description,
                        isSelected: isExerciseSelected(exercise),
                        resizingMode: .fit
                    )
                    .anyButton(.highlight) {
                        presenter.onExercisePressed(
                            exercise: exercise,
                            onExerciseSelectionChanged: delegate.onExerciseSelectionChanged
                        )
                    }
                    .accessibilityIdentifier("ExerciseList.\(exercise.name)")
                    .removeListRowFormatting()
                }
            } else {
                ContentUnavailableView(
                    "No Custom Exercises",
                    systemImage: "dumbbell",
                    description: Text("You have no custom exercises.")
                )
            }
        } header: {
            HStack {
                Text("Custom Exercises")
            Spacer()
                Button {
                    presenter.onAddExercisePressed()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Add exercise")
            }
        }
    }

    private var systemExercisesSection: some View {
        Section {
            ForEach(presenter.systemExercises) { exercise in
                CustomListCellView(
                    imageName: exercise.imageURL,
                    title: exercise.name,
                    subtitle: exercise.description,
                    isSelected: isExerciseSelected(exercise),
                    resizingMode: .fit
                )
                .anyButton(.highlight) {
                    presenter.onExercisePressed(
                        exercise: exercise,
                        onExerciseSelectionChanged: delegate.onExerciseSelectionChanged
                    )
                }
                .accessibilityIdentifier("ExerciseList.\(exercise.name)")
                .removeListRowFormatting()
            }
        } header: {
            Text("Official Exercises")
        }
    }

    private var noMatchesSection: some View {
        Section {
            ContentUnavailableView(
                "No Matching Exercises",
                systemImage: "line.3.horizontal.decrease",
                description: Text("No exercise matches every filter. Try clearing one.")
            )
        }
    }

    private var filteredExercisesSection: some View {
        Section {
            ForEach(presenter.filteredExercises) { exercise in
                CustomListCellView(
                    imageName: exercise.imageURL,
                    title: exercise.name,
                    subtitle: exercise.description,
                    isSelected: isExerciseSelected(exercise),
                    resizingMode: .fit
                )
                .anyButton(.highlight) {
                    presenter.onExercisePressed(
                        exercise: exercise,
                        onExerciseSelectionChanged: delegate.onExerciseSelectionChanged
                    )
                }
                .accessibilityIdentifier("ExerciseList.\(exercise.name)")
                .removeListRowFormatting()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onAddExercisePressed()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.glassProminent)
            .accessibilityLabel("Add exercise")
        }
    }
}

extension CoreBuilder {
    
    func exerciseListBuilderView(router: AnyRouter, delegate: ExerciseListBuilderDelegate) -> some View {
        ExerciseListBuilderView(
            presenter: ExerciseListBuilderPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showExerciseListBuilderView(delegate: ExerciseListBuilderDelegate) {
        router.showScreen(.push) { router in
            builder.exerciseListBuilderView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = ExerciseListBuilderDelegate()
    
    return RouterView { router in
        builder.exerciseListBuilderView(router: router, delegate: delegate)
    }
}
