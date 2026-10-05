import SwiftUI

/// The user's own week: sessions against goal, volume against last week, sets per muscle, PRs,
/// RPE, weight trend and nutrition adherence, with a one-line takeaway on top.
struct WeeklyReviewView: View {

    @State var presenter: WeeklyReviewPresenter

    var body: some View {
        let review = presenter.review
        List {
            Section {
                Text(review.takeaway)
                    .font(.sectionTitle)
            } header: {
                weekHeader(review)
            }

            Section("Training") {
                LabeledContent("Sessions", value: review.sessionsText)
                LabeledContent("Volume") {
                    VStack(alignment: .trailing) {
                        Text(review.volumeText)
                        if let change = review.volumeChangeText {
                            Text(change)
                                .font(.label)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let rpe = review.averageRPEText {
                    LabeledContent("Average RPE", value: rpe)
                }
            }

            if !review.setsPerMuscle.isEmpty {
                Section("Sets per Muscle") {
                    ForEach(review.setsPerMuscle, id: \.muscle) { entry in
                        LabeledContent(entry.muscle.name, value: entry.sets.formatted(.number.precision(.fractionLength(0...1))))
                    }
                }
            }

            if !review.personalRecords.isEmpty {
                Section("Personal Records") {
                    ForEach(Array(review.personalRecords.enumerated()), id: \.offset) { _, record in
                        LabeledContent {
                            Text(record.detail)
                        } label: {
                            Label {
                                Text(record.exerciseName)
                            } icon: {
                                Image(systemName: Symbol.personalRecord)
                                    .foregroundStyle(.personalRecord)
                            }
                        }
                    }
                }
            }

            if let strava = review.strava {
                Section("From Strava") {
                    LabeledContent("Activities", value: strava.count.formatted())
                    if strava.distanceMeters > 0 {
                        LabeledContent("Distance", value: Format.distance(meters: strava.distanceMeters, unit: presenter.distanceUnit))
                    }
                    LabeledContent("Moving Time", value: Format.duration(strava.movingTime))
                }
            }

            if review.weightText != nil || review.nutritionText != nil {
                Section("Body & Nutrition") {
                    if let weight = review.weightText {
                        LabeledContent("Weight", value: weight)
                    }
                    if let nutrition = review.nutritionText {
                        LabeledContent("Calories", value: nutrition)
                    }
                }
            }
        }
        .navigationTitle("Weekly Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Share", systemImage: Symbol.share) {
                    presenter.onSharePressed()
                }
                .disabled(presenter.isSharing)
            }
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    private func weekHeader(_ review: WeeklyReview) -> some View {
        HStack {
            Button {
                presenter.onPreviousWeekPressed()
            } label: {
                Label("Previous week", systemImage: "chevron.backward")
                    .tapTarget()
            }
            .labelStyle(.iconOnly)
            Spacer()
            Text(review.dateRangeText)
                .font(.rowDetail)
                .fontWeight(.semibold)
            Spacer()
            Button {
                presenter.onNextWeekPressed()
            } label: {
                Label("Next week", systemImage: "chevron.forward")
                    .tapTarget()
            }
            .labelStyle(.iconOnly)
            .disabled(!presenter.canShowNextWeek)
        }
        .textCase(nil)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.weeklyReviewView(router: router)
    }
}

extension CoreBuilder {

    func weeklyReviewView(router: AnyRouter) -> some View {
        WeeklyReviewView(
            presenter: WeeklyReviewPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }

}

extension CoreRouter {

    func showWeeklyReviewView() {
        router.showScreen(.push) { router in
            builder.weeklyReviewView(router: router)
        }
    }

}
