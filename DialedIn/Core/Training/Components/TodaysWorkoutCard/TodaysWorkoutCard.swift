//
//  TodaysWorkoutCard.swift
//  DialedIn
//
//  Created by Andrew Coyle on 09/03/2026.
//

import SwiftUI

struct TodaysWorkoutCardDelegate {
    let todaysWorkoutTemplate: WorkoutTemplateModel
}

struct TodaysWorkoutCard: View {
    
    @State var presenter: TodaysWorkoutCardPresenter
    let delegate: TodaysWorkoutCardDelegate
    
    var body: some View {
        DashboardCard(title: String(localized: "Today's Workout"), drawsSurface: false) {
            ZStack(alignment: .leading) {
                if presenter.isTodayRestDay {
                    restDayCard
                } else if presenter.isTodayCompleted {
                    workoutCompleted
                } else {
                    startWorkoutCard
                }
            }
        }
    }
    
    private var restDayCard: some View {
        RestDayCard()
    }
    
    private var workoutCompleted: some View {
        WorkoutCompletedCard(template: delegate.todaysWorkoutTemplate)
    }
    
    private var startWorkoutCard: some View {
        Button {
            presenter.onTodaysWorkoutPressed()
        } label: {
            TodaysWorkoutCardLabel(template: delegate.todaysWorkoutTemplate)
        }
    }
}

extension CoreBuilder {
    func todaysWorkoutCard(router: AnyRouter, delegate: TodaysWorkoutCardDelegate) -> some View {
        TodaysWorkoutCard(
            presenter: TodaysWorkoutCardPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                )
            ),
            delegate: delegate
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = TodaysWorkoutCardDelegate(todaysWorkoutTemplate: .mock)
    
    RouterView { router in
        List {
            Section {
                TabView {
                    Tab {
                        builder.todaysWorkoutCard(router: router, delegate: delegate)
                    }
                }
                .tabViewStyle(.page)
                .frame(height: 240)
                
            }
            .listSectionMargins(.all, 0)
        }
    }
}
