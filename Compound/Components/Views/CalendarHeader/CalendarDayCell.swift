//
//  CalendarDayCell.swift
//  Compound
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
                .foregroundStyle(.secondary)

            todayDot
        }
        .monospacedDigit()
        .fontWeight(isToday ? .semibold : .regular)
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

    private var todayDotStyle: AnyShapeStyle {
        AnyShapeStyle(.tint)
    }

    /// The selection is the soft fill behind the day, so the text keeps its own colours on it.
    private var dayNumberStyle: AnyShapeStyle {
        isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary)
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
            // The selected day is a soft system fill in place of its outline, as the system's own
            // date strips mark it: quieter than the solid tint capsule it replaces, which drew
            // the eye to the selection rather than to the days' rings. The fill adapts to light
            // and dark, so the ring keeps its contrast on it.
            if isSelected {
                Capsule()
                    .fill(.fill.secondary)
            } else if workoutColours.isEmpty {
                // No track behind workouts' strokes: they go round the whole day, and the gaps
                // between them stay clear.
                // `inset(by:)` half the line width keeps the whole stroke inside the capsule.
                // Stroking the boundary splits the line either side of the edge.
                Capsule()
                    .inset(by: Self.ringWidth / 2)
                    .stroke(trackStyle, lineWidth: Self.ringWidth)
            }

            if !workoutColours.isEmpty {
                ForEach(workoutColours.indices, id: \.self) { index in
                    CapsuleSegment(index: index, count: workoutColours.count, gap: Self.segmentGap, inset: Self.ringWidth / 2)
                        .stroke(
                            workoutColours[index].map { AnyShapeStyle(Color(hex: $0)) } ?? AnyShapeStyle(.tint),
                            style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: workoutColours.count > 1 ? .butt : .round)
                        )
                }
            } else if let marker, !marker.isEmpty {
                Capsule()
                    .inset(by: Self.ringWidth / 2)
                    .trim(from: 0, to: marker.fraction)
                    .stroke(progressStyle(for: marker), style: strokeStyle(for: marker))
            }
        }
    }

    private static let ringWidth: CGFloat = 2

    /// One mesocycle colour per workout on the day, empty for any other marker.
    private var workoutColours: [String?] {
        if case .sessions(let colours) = marker { return colours }
        return []
    }

    /// Between the strokes of a day with more than one workout.
    private static let segmentGap: CGFloat = Spacing.xs

    /// How far the capsule is inset from the cell's own width. The cell keeps its full seventh of
    /// the strip as a tap target; only the capsule narrows. Not private, because the header's
    /// "Today" button draws the same capsule over the edge cell and has to match.
    ///
    /// Half the gap between neighbouring capsules, which comes out at `Spacing.l`.
    static let capsuleInset: CGFloat = Spacing.s

    /// The unfilled remainder, and the whole stroke on a day with nothing logged. The selected
    /// day has no track: its fill stands in for the outline, and the track is drawn in that same
    /// fill so selecting a day does not look like it takes the outline away.
    private var trackStyle: AnyShapeStyle {
        AnyShapeStyle(.fill.secondary)
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

/// One of `count` equal strokes around a capsule, `gap` points apart. Drawn clockwise from the
/// top centre, so two workouts split at the top and bottom.
private struct CapsuleSegment: Shape {
    let index: Int
    let count: Int
    let gap: CGFloat
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        let radius = min(rect.width, rect.height) / 2
        var outline = Path()
        outline.move(to: CGPoint(x: rect.midX, y: rect.minY))
        outline.addRelativeArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius, startAngle: .degrees(-90), delta: .degrees(90))
        outline.addRelativeArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), radius: radius, startAngle: .degrees(0), delta: .degrees(90))
        outline.addRelativeArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius), radius: radius, startAngle: .degrees(90), delta: .degrees(90))
        outline.addRelativeArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius, startAngle: .degrees(180), delta: .degrees(90))
        outline.closeSubpath()
        guard count > 1 else { return outline }

        let perimeter = 2 * (rect.width + rect.height - 4 * radius) + 2 * .pi * radius
        let halfGap = perimeter > 0 ? gap / perimeter / 2 : 0
        return outline.trimmedPath(
            from: CGFloat(index) / CGFloat(count) + halfGap,
            to: CGFloat(index + 1) / CGFloat(count) - halfGap
        )
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

        // Training by mesocycle: one · two from different mesocycles · three, one outside any
        HStack(spacing: 0) {
            CalendarDayCell(day: today, marker: .sessions(colours: ["#3478F6"]), isToday: false, isSelected: false)
            CalendarDayCell(day: today, marker: .sessions(colours: ["#3478F6", "#FF9500"]), isToday: false, isSelected: false)
            CalendarDayCell(day: today, marker: .sessions(colours: ["#3478F6", "#34C759", nil]), isToday: false, isSelected: true)
        }

        // Nutrition: quarter · half · on target · within the 100kcal grace · over it
        HStack(spacing: 0) {
            CalendarDayCell(day: today, marker: .goalProgress(value: 550, goal: 2200, grace: 100), isToday: false, isSelected: false)
            CalendarDayCell(day: today, marker: .goalProgress(value: 1100, goal: 2200, grace: 100), isToday: true, isSelected: false)
            CalendarDayCell(day: today, marker: .goalProgress(value: 2200, goal: 2200, grace: 100), isToday: false, isSelected: false)
            CalendarDayCell(day: today, marker: .goalProgress(value: 2290, goal: 2200, grace: 100), isToday: false, isSelected: false)
            CalendarDayCell(day: today, marker: .goalProgress(value: 2650, goal: 2200, grace: 100), isToday: false, isSelected: false)
        }

        // The same five, selected: the soft fill, with each ring's progress on it
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
