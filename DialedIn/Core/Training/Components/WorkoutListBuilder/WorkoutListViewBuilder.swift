//
//  WorkoutsView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI

struct WorkoutListDelegateBuilder {
    var onWorkoutSelectionChanged: ((WorkoutTemplateModel) -> Void)?
}

struct WorkoutListViewBuilder: View {
    
    @State var presenter: WorkoutListPresenterBuilder
    
    let delegate: WorkoutListDelegateBuilder
    
    var body: some View {
        List {
            if presenter.searchText.isEmpty {
                if !presenter.userWorkoutTemplates.isEmpty {
                    userWorkoutTemplatesSection
                }
                systemWorkoutTemplatesSection
            } else {
                filteredWorkoutTemplatesSection
            }
        }
        .overlay {
            if !presenter.searchText.isEmpty && presenter.filteredWorkoutTemplates.isEmpty {
                ContentUnavailableView.search(text: presenter.searchText)
            }
        }
        .searchable(text: $presenter.searchText, placement: .toolbar, prompt: Text("Search workouts"))
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .navigationTitle("Workouts")
        .navigationSubtitle("\(presenter.workoutsCount) workouts")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presenter.onAddWorkoutPressed()
                } label: {
                    Image(systemName: Symbol.add)
                }
                .accessibilityLabel("Add workout")
            }
        }
    }
    
    private func workoutRow(_ workout: WorkoutTemplateModel) -> some View {
        HStack {
            WorkoutTemplateRow(workoutTemplate: workout)
            Image(systemName: "chevron.forward")
                .font(.rowDetail.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .anyButton(.highlight) {
            presenter.onWorkoutPressed(
                workout: workout,
                onWorkoutPressed: delegate.onWorkoutSelectionChanged
            )
        }
    }
    
    private var systemWorkoutTemplatesSection: some View {
        Section {
            ForEach(presenter.systemWorkoutTemplates) { workout in
                workoutRow(workout)
            }
        } header: {
            HStack {
                Text("Pre-Built Templates")
                Spacer()
                Text("\(presenter.systemWorkoutTemplates.count)")
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("Professional workout templates designed for common training programs.")
        }
    }

    private var userWorkoutTemplatesSection: some View {
        Section {
            ForEach(presenter.userWorkoutTemplates) { workout in
                workoutRow(workout)
            }
        } header: {
            HStack {
                Text("Custom Templates")
                Spacer()
                Text("\(presenter.userWorkoutTemplates.count)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var filteredWorkoutTemplatesSection: some View {
        Section {
            ForEach(presenter.filteredWorkoutTemplates) { workout in
                workoutRow(workout)
            }
        } header: {
            HStack {
                Text("Workout Templates")
                Spacer()
                Text("\(presenter.filteredWorkoutTemplates.count)")
                    .foregroundStyle(.secondary)
            }
        }
    }

}

extension CoreBuilder {
    func workoutListViewBuilder(router: AnyRouter, delegate: WorkoutListDelegateBuilder) -> some View {
        WorkoutListViewBuilder(
            presenter: WorkoutListPresenterBuilder(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    RouterView { router in
        WorkoutListViewBuilder(
            presenter: WorkoutListPresenterBuilder(
                interactor: CoreInteractor(container: container),
                router: CoreRouter(
                    router: router,
                    builder: CoreBuilder(interactor: CoreInteractor(container: container))
                )
            ),
            delegate: WorkoutListDelegateBuilder(
                onWorkoutSelectionChanged: { template in
                    print(template.name)
                }
            )
        )
    }
}
