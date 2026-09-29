//
//  TrainingView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI

struct TrainingDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct TrainingView<CalendarHeaderView: View, ActiveProgramView: View>: View {

    @State var presenter: TrainingPresenter
    let delegate: TrainingDelegate

    let profileTransitionId: String = "profile_button_transition"
    
    @ViewBuilder var calendarHeader: (CalendarHeaderDelegate, Binding<Bool>) -> CalendarHeaderView
    @ViewBuilder var activeProgramContent: (TrainingProgram) -> ActiveProgramView

    @Namespace private var namespace

    @State private var isCalendarExpanded = false

    var body: some View {
        List {
            if let program = presenter.activeTrainingProgram {
                activeProgramContent(program)
            } else {
                noScheduleView
            }

            moreSection
        }
        .navigationTitle("Training")
        .minimizingLargeTitleBar()
        .scrollIndicators(.hidden)
        .toolbar {
            toolbarContent
        }
        .safeAreaInset(edge: .top) {
            calendarHeader(
                CalendarHeaderDelegate(
                    onDatePressed: { date in
                        presenter.onDatePressed(date: date)
                    },
                    // Tapping a day opens that day's session; the screen has no "selected day"
                    // state for a highlight to reflect.
                    showsSelection: false,
                    markersByDay: {
                        presenter.loggedWorkoutMarkersByDay()
                    }
                ),
                $isCalendarExpanded
            )
        }
    }

    private var noScheduleView: some View {
        Section {
            ContentUnavailableView {
                Label("No Active Training Program", systemImage: Symbol.program)
            } description: {
                Text("Add a program to start compounding.")
            } actions: {
                Button {
                    presenter.onChooseProgramPressed()
                } label: {
                    Text("Choose Program")
                        .foregroundStyle(.onAccent)
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    private var moreSection: some View {
        Section("More") {
            ListRowButton(title: "Programs", systemImage: Symbol.library) {
                presenter.onTrainingProgramLibraryView()
            }
            ListRowButton(title: "Workout Library", systemImage: Symbol.workout) {
                presenter.onWorkoutLibraryPressed()
            }
            ListRowButton(title: "Start Empty Workout", systemImage: Symbol.add) {
                presenter.onStartEmptyWorkoutPressed()
            }
            ListRowButton(title: "Workout History", systemImage: Symbol.history) {
                presenter.onWorkoutHistoryPressed()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {

        #if DEV || MOCK
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onDevSettingsPressed()
            } label: {
                Image(systemName: "info")
            }
            .accessibilityLabel("Developer settings")
        }
        #endif

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isCalendarExpanded = true
            } label: {
                Image(systemName: Symbol.calendar)
            }
            .accessibilityLabel("Show calendar")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    presenter.onNewProgramPressed()
                } label: {
                    Label("New Program", systemImage: Symbol.program)
                }
                Button {
                    presenter.onNewWorkoutPressed()
                } label: {
                    Label("New Workout", systemImage: Symbol.workout)
                }
                Button {
                    presenter.onNewExercisePressed()
                } label: {
                    Label("New Exercise", systemImage: Symbol.exercise)
                }
            } label: {
                Image(systemName: Symbol.add)
            }
            .accessibilityLabel("Add training")
        }
        
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        
        ToolbarItem(placement: .topBarTrailing) {
            ProfileButton(
                action: {
                    presenter.onProfilePressed(transitionId: profileTransitionId, namespace: namespace)
                },
                imageUrl: presenter.userImageUrl
            )
            .matchedTransitionSource(id: profileTransitionId, in: namespace)
        }
    }
}

extension CoreBuilder {
    func trainingView(delegate: TrainingDelegate, router: AnyRouter) -> some View {
        TrainingView(
            presenter: TrainingPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            calendarHeader: { calendarDelegate, isCalendarExpanded in
                self.calendarHeaderView(
                    router: router,
                    delegate: calendarDelegate,
                    isCalendarExpanded: isCalendarExpanded
                )
            },
            activeProgramContent: { program in
                self.activeTrainingProgramView(
                    router: router,
                    delegate: ActiveTrainingProgramDelegate(program: program)
                )
            }
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = TrainingDelegate()
    RouterView { router in
        builder.trainingView(delegate: delegate, router: router)
    }
}
