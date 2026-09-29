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
                    .font(.headline)
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
                                .font(.caption)
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
                            Label(record.exerciseName, systemImage: "trophy.fill")
                        }
                    }
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
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) {
                    presenter.onClosePressed()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Share", systemImage: "square.and.arrow.up") {
                    presenter.onSharePressed()
                }
                .disabled(presenter.isSharing)
            }
        }
        .onAppear {
            presenter.onViewAppear()
        }
    }

    private func weekHeader(_ review: WeeklyReview) -> some View {
        HStack {
            Button("Previous week", systemImage: "chevron.left") {
                presenter.onPreviousWeekPressed()
            }
            .labelStyle(.iconOnly)
            Spacer()
            Text(review.dateRangeText)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button("Next week", systemImage: "chevron.right") {
                presenter.onNextWeekPressed()
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
        router.showScreen(.sheet) { router in
            builder.weeklyReviewView(router: router)
        }
    }

}
