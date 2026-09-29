import SwiftUI

struct CalendarHeaderDelegate {
    var onDatePressed: (Date) -> Void

    /// Whether a day is drawn as selected. Off for hosts that do not track a selected day —
    /// Training opens the tapped day's session rather than putting the screen into a state, so a
    /// filled cell there implies a selection the screen does not have.
    var showsSelection: Bool = true

    /// What each day is marked with, keyed by `startOfDay` and supplied in one call for the
    /// whole header — a session count in Training, calories against the day's goal in Nutrition.
    var markersByDay: () -> [Date: CalendarDayMarker]
}

struct CalendarHeaderView: View {

    @Environment(\.colorScheme) private var colorScheme

    @State var presenter: CalendarHeaderPresenter

    /// Driven by a toolbar button in the parent screen. The header owns the transition
    /// namespace, so it is what actually presents; the parent only asks.
    @Binding var isCalendarExpanded: Bool

    /// View state, not presenter state: bound to the presenter it wrote through `@Observable`
    /// on every scroll update, invalidating the whole header — all seven cells — mid-swipe.
    ///
    /// The leftmost day on screen, now that the strip pages by day rather than by week. Seven
    /// days are visible from here, which is what decides whether today is on screen.
    @State private var leadingDay: Date?

    @Namespace private var namespace

    var body: some View {
        // Built once per body pass and looked up per cell.
        let markers = presenter.markersByDay()

        return ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(presenter.days, id: \.self) { (day: Date) in
                    dayCell(day, marker: markers[day])
                        // A day is a page, so each cell is exactly a seventh of the strip. The
                        // side inset the week-paged version needed is gone with it: there is no
                        // page edge left to inset, and padding here would make the cells
                        // narrower than the step the scroll view snaps by.
                        .containerRelativeFrame(
                            .horizontal,
                            count: CalendarHeaderPresenter.visibleDayCount,
                            span: 1,
                            spacing: 0
                        )
                }
            }
            // Belongs on the layout inside the scroll view, not on the ScrollView,
            // or viewAligned paging has nothing to snap to.
            .scrollTargetLayout()
        }
        .frame(height: Self.rowHeight)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $leadingDay, anchor: .leading)
        .scrollTargetBehavior(.viewAligned)
        .overlay(alignment: todayButtonAlignment) {
            returnToTodayButton
        }
        .matchedTransitionSource(id: "calendar-header", in: namespace)
        .onAppear {
            if leadingDay == nil {
                leadingDay = presenter.currentWeekStart
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
                presenter.refreshToday()
            }
        }
        .onChange(of: presenter.focusedDate) { _, newValue in
            // A day picked in the expanded calendar is usually outside the seven the strip is
            // showing, so follow the selection — but only then. Tapping a visible cell must not
            // shunt the strip sideways under the finger.
            guard !presenter.isVisible(newValue, fromLeadingDay: leadingDay) else { return }
            withAnimation {
                leadingDay = presenter.weekStart(for: newValue)
            }
        }
        .onChange(of: isCalendarExpanded) { _, isExpanded in
            guard isExpanded else { return }
            presenter.showLargeCalendar("calendar-header", in: namespace) {
                isCalendarExpanded = false
            }
        }
    }

    // MARK: - Return to today

    /// Pinned to whichever edge today lies beyond, so the button sits on the side it will carry
    /// the strip towards.
    private var todayButtonAlignment: Alignment {
        presenter.isTodayAhead(ofLeadingDay: leadingDay) ? .trailing : .leading
    }

    /// Fades in only once today has scrolled off the strip, and returns to the week containing it
    /// rather than to the single day — a lone day on the leading edge reads as an odd half-week.
    ///
    /// Sized and shaped as a day cell, covering the edge one exactly: same seventh-of-the-strip
    /// width, same three-row column, same inset capsule. So it has to be *opaque* — the day it
    /// sits on is still drawn underneath.
    @ViewBuilder
    private var returnToTodayButton: some View {
        let isHidden = presenter.isTodayVisible(fromLeadingDay: leadingDay)
        let pointsForward = presenter.isTodayAhead(ofLeadingDay: leadingDay)

        VStack(spacing: 2) {
            Image(systemName: pointsForward ? "chevron.right" : "chevron.left")
                .font(.caption)
        }
        .monospaced()
        .fontWeight(.semibold)
        .foregroundStyle(Color.accentColor)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Capsule()
                    .fill(colorScheme.backgroundPrimary)
                Capsule()
                    .inset(by: 1)
                    .stroke(.tint, lineWidth: 2)
            }
            .padding(.horizontal, CalendarDayCell.capsuleInset)
        }
        .containerRelativeFrame(
            .horizontal,
            count: CalendarHeaderPresenter.visibleDayCount,
            span: 1,
            spacing: 0
        )
        .opacity(isHidden ? 0 : 1)
        // Hidden means gone: left in the hierarchy it would keep swallowing taps on the day
        // underneath it.
        .allowsHitTesting(!isHidden)
        .animation(.easeInOut(duration: 0.2), value: isHidden)
        .anyButton(.press) {
            presenter.onReturnToTodayPressed()
            withAnimation {
                leadingDay = presenter.weekStart(for: presenter.today)
            }
        }
        .padding(.vertical, 8)
    }

    private static let rowHeight: CGFloat = 70

    @ViewBuilder
    private func dayCell(_ day: Date, marker: CalendarDayMarker?) -> some View {
        CalendarDayCell(
            day: day,
            marker: marker,
            isToday: presenter.calendar.isDate(day, inSameDayAs: presenter.today),
            isSelected: presenter.isSelected(day),
            showsWeekday: true
        )
        // A plain tap rather than a zero-distance DragGesture: the scroll view cancels this
        // cleanly, where the drag gesture left `isPressing` stuck true when the scroll took
        // over. The expanded calendar is a toolbar button in the parent, not a long press.
        .onTapGesture {
            presenter.onDatePressed(day)
        }
        .accessibilityAddTraits(.isButton)
    }

}

extension CoreBuilder {
    
    func calendarHeaderView(
        router: AnyRouter,
        delegate: CalendarHeaderDelegate,
        isCalendarExpanded: Binding<Bool>
    ) -> some View {
        CalendarHeaderView(
            presenter: CalendarHeaderPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            ),
            isCalendarExpanded: isCalendarExpanded
        )
    }
    
}

// MARK: - Previews

/// Preview stand-ins for the two protocols this screen depends on, both of which are a single
/// method. `DevPreview.shared.container()` builds every manager in the app, and eighteen of its
/// sync engines open a SwiftData store and read it synchronously inside `init` — work the
/// header does not need, paid before anything renders.
@MainActor
private struct PreviewCalendarHeaderInteractor: CalendarHeaderInteractor {
    func trackEvent(event: LoggableEvent) { }
}

@MainActor
private struct PreviewCalendarHeaderRouter: CalendarHeaderRouter {
    func showCalendarViewZoom(
        delegate: CalendarDelegate,
        onDismiss: (() -> Void)?,
        onDidDismiss: (() -> Void)?,
        transitionId: String?,
        namespace: Namespace.ID
    ) { }
}

@MainActor
private func previewDelegate() -> CalendarHeaderDelegate {
    CalendarHeaderDelegate(
        onDatePressed: { date in
            print(date.formatted(date: .abbreviated, time: .omitted))
        },
        markersByDay: {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            return (-3...3).reduce(into: [Date: CalendarDayMarker]()) { markers, offset in
                guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return }
                markers[day] = .count(abs(offset))
            }
        }
    )
}

#Preview("Calendar Header") {
    @Previewable @State var isCalendarExpanded = false

    CalendarHeaderView(
        presenter: CalendarHeaderPresenter(
            interactor: PreviewCalendarHeaderInteractor(),
            router: PreviewCalendarHeaderRouter(),
            delegate: previewDelegate()
        ),
        isCalendarExpanded: $isCalendarExpanded
    )
}

#Preview("In a screen") {
    @Previewable @State var isCalendarExpanded = false

    NavigationStack {
        List {
            Text("Hello")
        }
        .navigationTitle("Calendar Header Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Stands in for the parent screen's button. The preview router does not present
            // anything, so this only shows the wiring.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCalendarExpanded = true
                } label: {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel("Show calendar")
            }
        }
        .safeAreaInset(edge: .top) {
            CalendarHeaderView(
                presenter: CalendarHeaderPresenter(
                    interactor: PreviewCalendarHeaderInteractor(),
                    router: PreviewCalendarHeaderRouter(),
                    delegate: previewDelegate()
                ),
                isCalendarExpanded: $isCalendarExpanded
            )
        }
    }
}

/// The full dependency graph, for checking the real routing into the expanded calendar.
/// Slow to start — that is `DevPreview`, not this view.
#Preview("Full DI") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        List {
            Text("Hello")
        }
        .safeAreaInset(edge: .top) {
            builder.calendarHeaderView(
                router: router,
                delegate: previewDelegate(),
                isCalendarExpanded: .constant(false)
            )
                .background(.bar)
        }
    }
}
