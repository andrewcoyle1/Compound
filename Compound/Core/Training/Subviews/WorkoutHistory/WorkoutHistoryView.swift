//
//  WorkoutHistoryView.swift
//  Compound
//
//  Created by Andrew Coyle
//

import SwiftUI

struct WorkoutHistoryDelegate {
    let onSessionSelectionChanged: ((WorkoutSessionModel) -> Void)?
}

struct WorkoutHistoryView<WorkoutSessionRow: View>: View {
    @Environment(\.layoutMode) private var layoutMode
    @Environment(\.scenePhase) private var scenePhase
    
    @State var presenter: WorkoutHistoryPresenter

    @ViewBuilder var workoutSessionRow: (WorkoutSessionRowDelegate) -> WorkoutSessionRow

    var body: some View {
        List {
            if presenter.isLoading && presenter.workoutSessions.isEmpty {
                loadingState
            } else if let user = presenter.currentUser, !presenter.workoutSessions.isEmpty {
                listContents(user: user)
            } else {
                // Also with no sessions: a signed-in user with none saw a "0" header over nothing.
                emptyState
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Workout History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }
    
    private var loadingState: some View {
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, Spacing.xxl)
            .removeListRowFormatting()
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Workout History", systemImage: Symbol.history)
        } description: {
            Text("Complete your first workout to see it here.")
        } actions: {
            Button {
                presenter.onReloadPressed()
            } label: {
                Text("Reload")
            }
            .buttonStyle(.bordered)
            .disabled(presenter.isLoading)
        }
    }
    
    private func listContents(user: UserModel) -> some View {
        Section {
            ForEach(presenter.workoutSessions) { session in
                workoutSessionRow(WorkoutSessionRowDelegate(session: session, author: user))
                    .anyButton(.highlight) {
                        presenter.onWorkoutSessionPressed(session: session, layoutMode: layoutMode)
                    }
            }
            .removeListRowFormatting()
            // Cards sit apart with a gap; a divider in it draws a hairline between two surfaces.
            .listRowSeparator(.hidden)
        } header: {
            HStack {
                Text("Completed Workouts")
                Spacer()
                Text("\(presenter.workoutSessions.count)")
                    .foregroundStyle(.secondary)
            }
            // The section margin is gone, so the header keeps the cards' gutter itself.
            .padding(.horizontal)
        }
        .listSectionSeparator(.hidden)
        // The margin would sit outside each card's own gutter and inset it twice.
        .listSectionMargins(.horizontal, 0)
    }
}

extension CoreBuilder {
    func workoutHistoryView(router: AnyRouter) -> some View {
        WorkoutHistoryView(
            presenter: WorkoutHistoryPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            workoutSessionRow: { delegate in
                self.workoutSessionRowView(router: router, delegate: delegate)
            }
        )
    }
}

extension CoreRouter {
    /// Browsing, so a push on the Training tab's stack; the system Back button closes it.
    func showWorkoutHistoryView() {
        router.showScreen(.push) { router in
            builder.workoutHistoryView(router: router)
        }
    }
}

#Preview("Functioning") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.workoutHistoryView(router: router)
        .navigationTitle("Workout History")
    }
    
}

#Preview("No Data") {
    let container = DevPreview.shared.container()
    let userWorkoutSessionSyncEngine = CollectionSyncEngine<WorkoutSessionModel>(
        remote: MockRemoteCollectionService(collection: []),
        managerKey: Keys.userWorkoutSessionManagerKey
    )
    let followingWorkoutSessionSyncEngine = CollectionGroupSyncEngine<WorkoutSessionModel>(
        remote: MockRemoteCollectionGroupService(collection: []),
        managerKey: Keys.followingWorkoutSessionsManagerKey
    )
    
    let activeWorkoutSessionPersistence = FileManagerDocumentPersistence<WorkoutSessionModel>()
    let mockLikeService = MockWorkoutSessionLikeService()
    container.register(
        WorkoutSessionManager.self,
        service: WorkoutSessionManager(
            likeService: mockLikeService,
            activeWorkoutSessionPersistence: activeWorkoutSessionPersistence,
            userWorkoutSessionSyncEngine: userWorkoutSessionSyncEngine,
            followingWorkoutSessionSyncEngine: followingWorkoutSessionSyncEngine
        )
    )
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.workoutHistoryView(router: router)
            .navigationTitle("Workout History")
    }
    
}
