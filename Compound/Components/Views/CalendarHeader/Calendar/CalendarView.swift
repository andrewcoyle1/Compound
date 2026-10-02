//
//  CalendarView.swift
//  Compound
//
//  Created by Andrew Coyle on 16/10/2025.
//

import SwiftUI

struct CalendarDelegate {
    /// The day the header is currently on, so the sheet opens there rather than on today.
    var selectedDate: Date = .now

    /// Whether `selectedDate` is drawn as selected. Off for hosts that do not track a selection,
    /// where the sheet is only a date picker.
    var showsSelection: Bool = true
    var onDateSelected: (Date, Date) -> Void
    /// Same map the week strip uses, so both mark days the same way.
    var markersByDay: () -> [Date: CalendarDayMarker] = { [:] }
}

struct CalendarView: View {

    @State var presenter: CalendarPresenter

    /// Scrolling is driven through a `ScrollViewProxy` rather than `scrollPosition(id:)`,
    /// because that binding resolves against the scroll target layout's immediate children and
    /// a `Section` splits each month into two of them — header and grid — leaving the
    /// initial position and the Today button without an anchor.
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        monthsScrollView
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
    }

    private var monthsScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                // Month titles scroll with their month. Pinned, they sat over the day grid and
                // needed a material of their own to stay legible.
                LazyVStack(spacing: Spacing.l) {
                    ForEach(presenter.months) { month in
                        Section {
                            monthGrid(month)
                        } header: {
                            // The id sits on the header rather than the `Section`, so
                            // `scrollTo` has a plain view to find and lands on the month title.
                            monthHeader(month)
                                .id(month.id)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onAppear {
                scrollProxy = proxy
            }
            .task {
                // A hop after the first layout pass: scrolling straight from `onAppear` asks
                // the lazy stack for a month it has not built yet.
                await Task.yield()
                // No animation — this is the sheet's opening position, not a movement.
                proxy.scrollTo(presenter.initialMonth, anchor: .top)
            }
        }
    }

    private func monthHeader(_ month: CalendarPresenter.Month) -> some View {
        Text(month.title)
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, Spacing.xs)
    }

    private func monthGrid(_ month: CalendarPresenter.Month) -> some View {
        LazyVGrid(columns: presenter.columns, spacing: Spacing.s) {
            ForEach(Array(month.days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    // Keeps the 1st in its own weekday column.
                    Color.clear
                        .frame(height: 1)
                }
            }
        }
        // The strip's margin, not the default 16 pt, so the columns are the same width as its
        // cells.
        .padding(.horizontal, CalendarHeaderView.sideMargin)
    }

    /// The same cell the week strip draws, at the same size and with its weekday letter, so the
    /// sheet reads as the expanded form of the header rather than a second calendar. The letter
    /// in every cell is why there is no weekday row above the grid.
    private func dayCell(_ day: Date) -> some View {
        CalendarDayCell(
            day: day,
            marker: presenter.marker(for: day),
            isToday: presenter.isToday(day),
            isSelected: presenter.isSelected(day)
        )
        .onTapGesture {
            presenter.onDateSelected(day: day)
        }
        .accessibilityAddTraits(.isButton)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {

        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                withReducedMotionAnimation(.standard) {
                    scrollProxy?.scrollTo(presenter.currentMonth, anchor: .top)
                }
            } label: {
                Text("Today")
            }
        }
    }

}

extension CoreBuilder {

    func calendarView(router: AnyRouter, delegate: CalendarDelegate) -> some View {
        CalendarView(
            presenter: CalendarPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            )
        )
    }

}

extension CoreRouter {

    /// Tall enough for a month title, six week rows and the toolbar. The previous 0.45 fraction
    /// cut the last row off on shorter devices, and the rows grew when they took on the week
    /// strip's weekday letter.
    static let calendarSheetHeight: CGFloat = 520

    func showCalendarView(delegate: CalendarDelegate) {
        router.showScreen(.sheetConfig(config: ResizableSheetConfig(detents: [.height(Self.calendarSheetHeight), .large], dragIndicator: .visible))) { router in
            builder.calendarView(router: router, delegate: delegate)
        }
    }

    /// `onDidDismiss` runs after the router has finished tearing the sheet down, which is the
    /// only safe point to present another screen in response to the selection — anything
    /// presented before that is swept away by the router's clean-up pass.
    func showCalendarViewZoom(
        delegate: CalendarDelegate,
        onDismiss: (() -> Void)? = nil,
        onDidDismiss: (() -> Void)? = nil,
        transitionId: String?,
        namespace: Namespace.ID
    ) {
        router.showScreenWithZoomTransition(
            .sheetConfig(config: ResizableSheetConfig(detents: [.height(Self.calendarSheetHeight), .large], dragIndicator: .visible)),
            onDismiss: onDismiss,
            onDidDismiss: onDidDismiss,
            transitionID: transitionId,
            namespace: namespace) { router in
                builder.calendarView(router: router, delegate: delegate)
            }
    }
}

// MARK: - Previews

/// `CalendarInteractor` is empty and `CalendarRouter` only needs an `AnyRouter`, so the sheet
/// previews without `DevPreview`, whose container opens eighteen SwiftData stores in `init`.
private struct PreviewCalendarInteractor: CalendarInteractor { }

@MainActor
private struct PreviewCalendarRouter: CalendarRouter {
    let router: AnyRouter
}

@MainActor
private func previewCalendarDelegate() -> CalendarDelegate {
    CalendarDelegate(
        selectedDate: .now,
        onDateSelected: { date, _ in
            print("Date selected: \(date.formatted(date: .abbreviated, time: .omitted))")
        },
        markersByDay: {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            return (-40...5).reduce(into: [Date: CalendarDayMarker]()) { markers, offset in
                guard offset % 3 != 0, let day = calendar.date(byAdding: .day, value: offset, to: today) else { return }
                markers[day] = .goalProgress(value: Double(1200 + (offset * 97) % 1400), goal: 2200, grace: 100)
            }
        }
    )
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            RouterView { router in
                CalendarView(
                    presenter: CalendarPresenter(
                        interactor: PreviewCalendarInteractor(),
                        router: PreviewCalendarRouter(router: router),
                        delegate: previewCalendarDelegate()
                    )
                )
            }
            .presentationDetents([.height(CoreRouter.calendarSheetHeight), .large])
        }
}
