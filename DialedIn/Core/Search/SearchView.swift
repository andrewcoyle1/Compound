//
//  SearchView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 22/10/2025.
//

import SwiftUI

/// The Search tab. Empty, it offers a row of shortcuts for the things a person records rather
/// than builds, and the searches they came back to. With a query, it searches every library at
/// once and the rows act: a workout starts, a person opens.
struct SearchView: View {

    @Environment(\.colorScheme) private var colorScheme
    @State var presenter: SearchPresenter

    let profileButtonTransition: String = "profile_button_transition"
    
    @Namespace private var namespace
    
    var body: some View {
        List {
            if !presenter.hasSearchQuery {
                if presenter.quickActions.isEmpty && presenter.recentQueries.isEmpty {
                    noShortcutsSection
                } else {
                    quickActionsSection
                    recentSearchesSection
                }
                inviteCodeSection
            } else if presenter.hasResults || presenter.isLoadingPeople {
                usersSection
                exercisesSection
                workoutsSection
                recipesSection
                ingredientsSection
            } else {
                emptyResultsSection
            }
        }
        .listSectionMargins(.horizontal, 0)
        .listRowSeparator(.hidden)
        .navigationTitle("Search")
        .minimizingLargeTitleBar()
        .searchable(
            text: $presenter.searchString,
            placement: .toolbar,
            prompt: Text("Exercises, workouts, foods, people")
        )
        .onSubmit(of: .search) {
            presenter.onSearchSubmitted()
        }
        .toolbar {
            toolbarContent
        }
        .onChange(of: presenter.searchString) {
            presenter.performUnifiedSearch()
        }
        .onFirstTask {
            await presenter.loadRecentSearches()
        }
        .scrollIndicators(.hidden)
        .alert("Enter invite code", isPresented: $presenter.isEnteringInviteCode) {
            TextField("Code", text: $presenter.inviteCodeInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Join") {
                Task { await presenter.onInviteCodeSubmitted() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The 8-character code from a friend's invite link.")
        }
    }

    /// For an invite link opened on another device than the one with the app.
    private var inviteCodeSection: some View {
        Section {
            Label("Enter invite code", systemImage: "person.badge.plus")
                .frame(maxWidth: .infinity, alignment: .leading)
                .tappableBackground()
                .anyButton(.highlight) {
                    presenter.onEnterInviteCodePressed()
                }
                .foregroundStyle(.primary)
        }
    }

    /// One horizontal row rather than the two-column grid it replaced: shortcuts are a way in,
    /// not the screen's content.
    private var quickActionsSection: some View {
        Section {
            if presenter.quickActions.isEmpty {
                Button("Choose Shortcuts") {
                    presenter.onChooseShortcutsPressed()
                }
                .padding(.horizontal)
                .removeListRowFormatting()
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(presenter.quickActions) { action in
                            QuickActionChip(title: action.title, systemImage: action.systemImage)
                                .anyButton(.press) {
                                    presenter.onQuickActionPressed(action)
                                }
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)
                .removeListRowFormatting()
            }
        }
    }

    @ViewBuilder
    private var recentSearchesSection: some View {
        if !presenter.recentQueries.isEmpty {
            Section {
                ForEach(presenter.recentQueries, id: \.self) { query in
                    Label(query, systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tappableBackground()
                        .anyButton(.highlight) {
                            presenter.onRecentSearchTapped(query: query)
                        }
                }
                .foregroundStyle(.primary)
            } header: {
                HStack {
                    Text("Recent")
                    Spacer()
                    Button("Clear") {
                        presenter.onClearRecentSearchesPressed()
                    }
                    .font(.caption)
                }
            }
        }
    }

    /// `ContentUnavailableView` rather than a hand-rolled stack, so every empty state in the app
    /// looks the same.
    private var emptyResultsSection: some View {
        Section {
            ContentUnavailableView.search(text: presenter.searchString)
                .removeListRowFormatting()
        }
    }

    /// Every shortcut turned off and nothing searched yet. Without this the tab opened onto a
    /// blank list with no way back to the Shortcuts screen.
    private var noShortcutsSection: some View {
        Section {
            ContentUnavailableView {
                Label("Search", systemImage: "magnifyingglass")
            } description: {
                Text("Find exercises, workouts, foods and people, or pick shortcuts to show here.")
            } actions: {
                Button("Choose Shortcuts") {
                    presenter.onChooseShortcutsPressed()
                }
            }
            .removeListRowFormatting()
        }
    }

    /// The only section that waits on the network, so the only one with a spinner.
    @ViewBuilder
    private var usersSection: some View {
        if !presenter.filteredUsers.isEmpty || presenter.isLoadingPeople {
            Section {
                ForEach(presenter.filteredUsers) { user in
                    UserRowView(user: user) {
                        FollowButton(state: presenter.followState(for: user)) {
                            presenter.onFollowButtonPressed(user: user)
                        }
                    }
                    .tappableBackground()
                    .anyButton(.highlight) {
                        presenter.onUserPressed(user: user)
                    }
                    .removeListRowFormatting()
                }
            } header: {
                HStack {
                    Text("People")
                    if presenter.isLoadingPeople {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var exercisesSection: some View {
        if !presenter.filteredExercises.isEmpty {
            searchItemSection(
                header: String(localized: "Exercises"),
                items: presenter.filteredExercises,
                action: { item in
                    guard let item = item as? ExerciseModel else { return }
                    presenter.onExercisePressed(exercise: item)
                }
            )
        }
    }

    @ViewBuilder
    private var workoutsSection: some View {
        if !presenter.filteredWorkoutTemplates.isEmpty {
            Section {
                ForEach(presenter.filteredWorkoutTemplates) { workout in
                    let subtitle = workout.exercises.map { $0.exercise.name }.joined(separator: ", ")
                    HStack {
                        CustomListCellView(
                            imageName: workout.imageURL,
                            title: workout.name,
                            subtitle: subtitle.isEmpty ? nil : subtitle
                        )
                        .anyButton(.highlight) {
                            presenter.onWorkoutPressed(workout: workout)
                        }
                        Button("Start") {
                            presenter.onStartWorkoutPressed(workout: workout)
                        }
                        .buttonStyle(.glassProminent)
                        .padding(.trailing)
                    }
                    .removeListRowFormatting()
                }
            } header: {
                Text("Workouts")
            }
        }
    }

    @ViewBuilder
    private var recipesSection: some View {
        if !presenter.filteredRecipeTemplates.isEmpty {
            searchItemSection(
                header: String(localized: "Recipes"),
                items: presenter.filteredRecipeTemplates,
                action: { item in
                    guard let item = item as? RecipeTemplateModel else { return }
                    presenter.onRecipePressed(recipe: item)
                }
            )
        }
    }

    @ViewBuilder
    private var ingredientsSection: some View {
        if !presenter.filteredFoods.isEmpty {
            searchItemSection(
                header: String(localized: "Foods"),
                items: presenter.filteredFoods,
                action: { item in
                    guard let item = item as? FoodModel else { return }
                    presenter.onIngredientPressed(ingredient: item)
                }
            )
        }
    }
    
    @ViewBuilder
    private func searchItemSection(header: String, items: [any SearchListItem], action: @escaping (any SearchListItem) -> Void) -> some View {
        Section {
            ForEach(items, id: \.id) { item in
                CustomListCellView(
                    imageName: item.imageURL,
                    title: item.name,
                    subtitle: item.description
                )
                .anyButton(.highlight) {
                    action(item)
                }
                .removeListRowFormatting()
            }
        } header: {
            Text(header)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ProfileButton(
                action: {
                    presenter.onProfilePressed(transitionId: profileButtonTransition, namespace: namespace)
                },
                imageUrl: presenter.userImageUrl
            )
            .matchedTransitionSource(id: profileButtonTransition, in: namespace)
        }
    }
}

protocol SearchListItem: Identifiable {
    var id: String { get }
    var name: String { get }
    var description: String? { get }
    var imageURL: String? { get }
}

/// One shortcut in the empty state's row.
private struct QuickActionChip: View {

    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(colorScheme.backgroundPrimary, in: Capsule())
    }
}

extension CoreBuilder {
    func searchView(router: AnyRouter) -> some View {
        SearchView(
            presenter: SearchPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)

    RouterView { router in
        builder.searchView(router: router)
    }
}
