//
//  CalendarDayCell.swift
//  DialedIn
//
//  Created by Andrew Coyle on 16/09/2026.
//

import SwiftUI

/// One day, shared by the week strip in `CalendarHeaderView` and the month grid in
/// `CalendarView`, so the two cannot drift apart. The expanded calendar used a plain circle
/// and no activity badge, which read as a different component entirely.
struct CalendarDayCell: View {

    let day: Date

    /// What the host screen recorded for this day: nil when nothing was logged.
    let marker: CalendarDayMarker?
    let isToday: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text(day.formatted(.dateTime.day()))
                .font(.body)
                .foregroundStyle(dayNumberStyle)
            Text(day.formatted(.dateTime.weekday(.short)))
                .font(.subheadline)
                .foregroundStyle(isSelected ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.secondary))

            todayDot
        }
        .monospacedDigit()
        .fontWeight(isSelected || isToday ? .semibold : .regular)
        .padding(.vertical, Spacing.m)
        .frame(maxWidth: .infinity)
        .background {
            outline
                .padding(.horizontal, Self.capsuleInset)
        }
        .overlay(alignment: .topTrailing) {
            if let badgeCount = marker?.badgeCount {
                badge(badgeCount)
            }
        }
        .contentShape(.rect)
        .reducedMotionAnimation(.quick, value: isSelected)
        // One element for the whole day. Read separately, the cell was "M", "14": no month, no
        // selection, and nothing of the ring or the badge.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityValue: String {
        [isToday ? String(localized: "Today") : nil, marker?.accessibilityDescription]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    /// Always in the layout, only visible for today — an `if` here would make today's cell
    /// taller than its neighbours and knock the row out of alignment.
    private var todayDot: some View {
        Circle()
            .fill(isToday ? todayDotStyle : AnyShapeStyle(.clear))
            .frame(width: 4, height: 4)
    }

    /// Inverted on the selected cell, which is filled with the tint the dot would otherwise use.
    private var todayDotStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.tint)
    }

    private var dayNumberStyle: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(.onAccent)
        } else if isToday {
            return AnyShapeStyle(.tint)
        } else {
            return AnyShapeStyle(.primary)
        }
    }

    /// The capsule behind the day, and its stroke.
    ///
    /// A `count` marker fills the whole stroke — the day either has something on it or it does
    /// not. A `goalProgress` marker draws the stroke as a ring: an empty track with the achieved
    /// fraction on top, turning red once the goal plus its grace allowance is passed. Today is
    /// marked by the dot under the number, never by this stroke, so a marked day always means
    /// there is something on that day.
    @ViewBuilder
    private var outline: some View {
        ZStack {
            // No fill: the centre shows the header's own background through the ring.

            // The selection sits *inside* the ring rather than under it, with a hairline of the
            // cell surface between them. Filling the whole capsule put the ring on the boundary
            // between two surfaces, which is what made it depend on the selection to stay legible.
            if isSelected {
                Capsule()
                    .fill(.tint)
                    .padding(Self.ringWidth + 1.5)
            }

            // `inset(by:)` half the line width keeps the whole stroke inside the capsule.
            // Stroking the boundary splits the line either side of the edge.
            Capsule()
                .inset(by: Self.ringWidth / 2)
                .stroke(trackStyle, lineWidth: Self.ringWidth)

            if let marker, !marker.isEmpty {
                Capsule()
                    .inset(by: Self.ringWidth / 2)
                    .trim(from: 0, to: marker.fraction)
                    .stroke(progressStyle(for: marker), style: strokeStyle(for: marker))
            }
        }
    }

    private static let ringWidth: CGFloat = 2

    /// How far the capsule is inset from the cell's own width. The cell keeps its full seventh of
    /// the strip as a tap target; only the capsule narrows. Not private, because the header's
    /// "Today" button draws the same capsule over the edge cell and has to match.
    ///
    /// Half the gap between neighbouring capsules, which comes out at `Spacing.l`.
    static let capsuleInset: CGFloat = Spacing.s

    /// The unfilled remainder, and the whole stroke on a day with nothing logged. One colour in
    /// every state now that the ring never overlaps the selection.
    private var trackStyle: AnyShapeStyle {
        AnyShapeStyle(.secondary)
    }

    /// The ring carries the status, in three steps: neutral while the day is still in progress,
    /// green once the goal is met, red once the grace allowance on top of it is used up too.
    ///
    /// Neutral rather than green from the start matters — a half-filled green ring would read as
    /// approval of a day that is only half eaten. `count` markers stay neutral throughout; a
    /// logged session is a fact, not a verdict.
    private func progressStyle(for marker: CalendarDayMarker) -> AnyShapeStyle {
        if marker.isOverGoal {
            return AnyShapeStyle(Color.danger.opacity(0.5))
        }
        if marker.isGoalMet {
            return AnyShapeStyle(Color.success.opacity(0.5))
        }
        // Calories wear their own colour, matching the calorie bar in the macro header below.
        if case .goalProgress = marker {
            return AnyShapeStyle(Color.calories)
        }
        return AnyShapeStyle(.tint)
    }

    /// Met and over-goal used to differ only by the ring's hue (green vs. red), which colour-blind
    /// people can't reliably tell apart. Over-goal now also dashes, so the two differ by shape.
    private func strokeStyle(for marker: CalendarDayMarker) -> StrokeStyle {
        StrokeStyle(
            lineWidth: Self.ringWidth,
            lineCap: .round,
            dash: marker.ringIsDashed ? [Self.ringWidth * 1.5, Self.ringWidth * 1.5] : []
        )
    }

    private func badge(_ count: Int) -> some View {
        Text(count > 9 ? "9+" : "\(count)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.onAccent)
            .padding(Spacing.xs)
            .background {
                Circle()
                    .fill(.tint)
            }
            .offset(x: 10 - Self.capsuleInset, y: -6)
    }
}

#Preview {
    let today = Date()

    return VStack(spacing: Spacing.xl) {
        // Training: today · today+selected · one session · several · nothing
        HStack(spacing: 0) {
            CalendarDayCell(day: today, marker: nil, isToday: true, isSelected: false)
            CalendarDayCell(day: today, marker: .count(1), isToday: true, isSelected: true)
            CalendarDayCell(day: today, marker: .count(1), isToday: false, isSelected: false)
            CalendarDayCell(day: today, marker: .count(3), isToday: false, isSelected: false)
            CalendarDayCell(day: today, marker: nil, isToday: false, isSelected: false)
        }

        // Nutrition: quarter · half · on target · within the 100kcal grace · over it
        HStack(spacing: 0) {
            CalendarDayCell(day: today, marker: .goalProgress(value: 550, goal: 2200, grace: 100), isToday: false, isSelected: false)
            CalendarDayCell(day: today, marker: .goalProgress(value: 1100, goal: 2200, grace: 100), isToday: true, isSelected: false)
            CalendarDayCell(day: today, marker: .goalProgress(value: 2200, goal: 2200, grace: 100), isToday: false, isSelected: false)
            CalendarDayCell(day: today, marker: .goalProgress(value: 2290, goal: 2200, grace: 100), isToday: false, isSelected: false)
            CalendarDayCell(day: today, marker: .goalProgress(value: 2650, goal: 2200, grace: 100), isToday: false, isSelected: false)
        }

        // The same five, selected, where the capsule is already tint-filled
        HStack(spacing: 0) {
            CalendarDayCell(day: today, marker: .goalProgress(value: 550, goal: 2200, grace: 100), isToday: false, isSelected: true)
            CalendarDayCell(day: today, marker: .goalProgress(value: 1100, goal: 2200, grace: 100), isToday: false, isSelected: true)
            CalendarDayCell(day: today, marker: .goalProgress(value: 2200, goal: 2200, grace: 100), isToday: false, isSelected: true)
            CalendarDayCell(day: today, marker: .goalProgress(value: 2290, goal: 2200, grace: 100), isToday: false, isSelected: true)
            CalendarDayCell(day: today, marker: .goalProgress(value: 2650, goal: 2200, grace: 100), isToday: false, isSelected: true)
        }
    }
    .padding()
}
