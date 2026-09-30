//
//  TrainingAccessoryView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 17/10/2025.
//

import SwiftUI

struct TrainingAccessoryDelegate {
    var active: WorkoutSessionModel
}

struct TrainingAccessoryView: View {

    @State var presenter: TrainingAccessoryPresenter
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let delegate: TrainingAccessoryDelegate

    var body: some View {
        // The skip button sits beside the main button rather than inside it: nested, VoiceOver
        // could not reach it, since the main button reads as one element.
        HStack(spacing: 0) {
            Button {
                presenter.reopenActiveSession()
            } label: {
                summary
                    .frame(maxWidth: .infinity)
                    .padding(.leading)
                    .padding(.trailing, showsSkipRest ? 0 : Spacing.l)
                    .tappableBackground()
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)

            if showsSkipRest {
                skipRestButton
            }
        }
        // The accessory is a fixed-height capsule: past AX1 even one line no longer fits in it.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// Inline beside the minimised tab bar, or text too large for two lines in the fixed-height
    /// capsule (two lines overflowed it from XXL up).
    private var isInline: Bool {
        placement == .inline || dynamicTypeSize > .xLarge
    }

    /// Dropped only beside the minimised tab bar, not for large text: the name truncates first.
    private var showsSkipRest: Bool {
        presenter.isRestActive && placement != .inline
    }

    /// "Resume workout, Push Day, 12 minutes" — one label for the whole button.
    private var accessibilityLabel: String {
        let elapsedMinutes = max(0, Int(Date().timeIntervalSince(delegate.active.dateCreated) / 60))
        return String(localized: "Resume workout, \(delegate.active.name), \(elapsedMinutes) minutes")
    }

    /// Music's MiniPlayer shape: a leading visual, title over subtitle, and the one live value
    /// trailing. Inline it keeps the ring, the name and the timer.
    private var summary: some View {
        HStack(spacing: Spacing.m) {
            progressRing
            if isInline {
                workoutName
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    workoutName
                    Text(presenter.progressLabel)
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Spacing.s)
            timer
        }
    }

    /// Sets done, as a ring around the workout symbol. Fixed, not scaled: the capsule's height is.
    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.tintedSurface(.accentColor), lineWidth: 3)
            Circle()
                .trim(from: 0, to: presenter.progress)
                .stroke(.tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: Symbol.workout)
                .font(.label.weight(.semibold))
                .foregroundStyle(.tint)
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }

    private var workoutName: some View {
        Text(delegate.active.name)
            .font(.rowDetail)
            .fontWeight(.semibold)
            .lineLimit(1)
    }

    /// Rest counts down in the accent; otherwise the elapsed time, secondary. No "Rest:" or
    /// "Elapsed:" prefix: the colour and the skip button say which it is. `restEndTime` clears
    /// when the rest ends, which redraws this back to the elapsed time.
    @ViewBuilder
    private var timer: some View {
        let now = Date()
        if let end = presenter.restEndTime, now < end {
            Text(timerInterval: now...end)
                .font(.metricSmall)
                .foregroundStyle(.tint)
        } else {
            Text(delegate.active.dateCreated, style: .timer)
                .font(.metricSmall)
                .foregroundStyle(.secondary)
        }
    }

    private var skipRestButton: some View {
        Button {
            presenter.onSkipRestPressed()
        } label: {
            Image(systemName: "forward.end.fill")
                .font(.rowTitle)
                .frame(width: ControlSize.row, height: ControlSize.row)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.trailing, Spacing.s)
        .accessibilityLabel("Skip rest")
    }
}

extension CoreBuilder {
    func trainingAccessoryView(router: AnyRouter, delegate: TrainingAccessoryDelegate) -> some View {
        return TrainingAccessoryView(
            presenter: TrainingAccessoryPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView(addNavigationStack: false) { router in
        TabView {
            Tab {
                Text("Tab")
            } label: {
                Text("Tab")
            }
        }
        .tabViewBottomAccessory {
            builder.trainingAccessoryView(
                router: router, 
                delegate: TrainingAccessoryDelegate(active: .mock)
            )
        }
    }
}
