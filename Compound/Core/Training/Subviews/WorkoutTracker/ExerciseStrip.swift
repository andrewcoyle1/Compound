//
//  ExerciseStrip.swift
//  Compound
//
//  The workout as a row of thumbnails over the card, one per block, each underlined with its
//  progress. A tap opens that block on the card. Behind `WorkoutSettings.showsExerciseStrip`,
//  which also slides the card in from the side of the strip it was picked from.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    var showsExerciseStrip: Bool { interactor.workoutSettings.showsExerciseStrip }

    var stripItems: [ActiveWorkout.StripItem] {
        ActiveWorkout.stripProgress(for: workoutSession.exercises, currentExerciseId: currentExercise?.id)
    }

    /// The card's block, by its first exercise.
    var currentBlockId: String? {
        guard let current = currentExercise?.id else { return nil }
        return ActiveWorkout.blocks(workoutSession.exercises).first { $0.contains(current) }?.first
    }

    /// Keys the list with the strip on, so a new block brings a new list in from the side it lies
    /// on (`CardSwapEdge`). `nil` with the strip off: the list keeps one identity.
    var cardListId: String? {
        showsExerciseStrip ? currentBlockId : nil
    }

    var blockOrder: [[String]] { ActiveWorkout.blocks(workoutSession.exercises) }

    /// Opens the tapped block on the card; the block already there stays as it is.
    func onStripItemSelected(_ itemId: String) {
        guard itemId != currentBlockId else { return }
        interactor.playHaptic(option: .selection)
        setFocus(itemId, reason: .strip)
    }
}

/// The thumbnails. A plain view: the presenter's items in, the tapped item's id out.
struct ExerciseStrip: View {

    let items: [ActiveWorkout.StripItem]
    let onSelect: (String) -> Void
    /// Up Next's reordering, on the strip's items while the strip stands in for that list.
    var onDoNext: (String) -> Void = { _ in }
    var onDoLater: (String) -> Void = { _ in }
    /// The strip's last item: Add Exercise, standing in for the list's row while the strip is up.
    var onAddExercise: () -> Void = {}

    @ScaledMetric(relativeTo: .body) private var side = ControlSize.thumbnail

    private var currentId: String? { items.first(where: \.isCurrent)?.id }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: Spacing.s) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item.id)
                        } label: {
                            thumbnail(item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if !item.isCurrent && !item.isComplete {
                                Button { onDoNext(item.id) } label: { Label("Do Next", systemImage: Symbol.doNext) }
                                Button { onDoLater(item.id) } label: { Label("Do Later", systemImage: Symbol.doLater) }
                            }
                        }
                        .id(item.id)
                        .accessibilityLabel(item.names.formatted(.list(type: .and)))
                        .accessibilityValue(accessibilityValue(item))
                        .accessibilityAddTraits(item.isCurrent ? .isSelected : [])
                        .accessibilityHint("Opens this exercise")
                    }
                    Button(action: onAddExercise) {
                        addThumbnail
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add Exercise")
                    .accessibilityIdentifier("WorkoutTracker.strip.addExercise")
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
            // As tall as a thumbnail: a horizontal scroll view otherwise takes all the bar offers.
            .fixedSize(horizontal: false, vertical: true)
            // A reader, not a second `scrollPosition`: the strip follows the card, never drives it.
            .onAppear { proxy.scrollTo(currentId, anchor: .center) }
            .onChange(of: currentId) { _, id in
                withReducedMotionAnimation(.standard) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
        .accessibilityIdentifier("WorkoutTracker.exerciseStrip")
    }

    /// A superset's members sit side by side under one ring and one progress bar: the strip
    /// shows it as the one block it is on the card.
    private func thumbnail(_ item: ActiveWorkout.StripItem) -> some View {
        let count = max(item.imageNames.count, 1)
        let width = side * CGFloat(count) + Spacing.xxs * CGFloat(count - 1)
        return VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xxs) {
                ForEach(Array(zip(item.names, item.imageNames).enumerated()), id: \.offset) { _, member in
                    image(name: member.0, imageName: member.1)
                        .frame(width: side, height: side)
                }
            }
            .clipShape(.rect(cornerRadius: Radius.s, style: .continuous))
            // The current block is ringed as well as tinted, so it is not marked by colour alone.
            .overlay {
                if item.isCurrent {
                    RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                        .strokeBorder(.tint, lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let letter = item.supersetLetter {
                    Text(letter)
                        .chipStyle(tint: .superset, filled: true)
                        .offset(x: Spacing.xs, y: -Spacing.xs)
                }
            }
            ProgressView(value: item.fraction)
                .tint(item.isComplete ? Color.success : item.isCurrent ? Color.accentColor : Color.secondary)
                .frame(width: width)
        }
        .padding(.vertical, Spacing.xs)
        .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
        .contentShape(.rect)
    }

    /// A plus in a thumbnail's frame, with the bar's space left under it so it lines up.
    private var addThumbnail: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: Symbol.add)
                .iconSize(.medium)
                .foregroundStyle(.tint)
                .frame(width: side, height: side)
                .background(Color.surface)
                .clipShape(.rect(cornerRadius: Radius.s, style: .continuous))
            ProgressView(value: 0)
                .frame(width: side)
                .hidden()
        }
        .padding(.vertical, Spacing.xs)
        .frame(minWidth: ControlSize.row, minHeight: ControlSize.row)
        .contentShape(.rect)
    }

    @ViewBuilder
    private func image(name: String, imageName: String?) -> some View {
        if let imageName, !imageName.isEmpty {
            ExerciseImageView(name: name, imageName: imageName, resizingMode: .fit)
        } else {
            Image(systemName: Symbol.exercise)
                .iconSize(.medium)
                .foregroundStyle(.secondary)
                .frame(width: side, height: side)
                .background(Color.surface)
        }
    }

    /// "2 of 4 sets, current".
    private func accessibilityValue(_ item: ActiveWorkout.StripItem) -> String {
        let sets = String(localized: "\(item.doneWorkingSets) of \(item.totalWorkingSets) sets")
        return item.isCurrent ? String(localized: "\(sets), current") : sets
    }
}

// MARK: - The card swap

/// Which side the card list comes in from when its block changes, worked out once per move
/// against the order the old block was shown in (so Do Later still reads as forward).
///
/// Held by the view rather than set by the presenter: Next, Up Next, Do Later, swap and delete
/// all move the card without going through `setFocus`, and the list going out keeps the
/// transition it was last drawn with, so an edge stored with the move reached only the incoming
/// list. `CardPush` asks here when it runs, and both lists agree.
@MainActor
final class CardSwapEdge {
    private var shownBlockId: String?
    private var shownOrder: [[String]] = []
    private var edge: Edge = .trailing

    /// The edge of the move to `blockId`, or of the last move when the block has not changed.
    @discardableResult
    func edge(to blockId: String?, order: [[String]]) -> Edge {
        if blockId != shownBlockId {
            edge = ActiveWorkout.entryEdge(from: shownBlockId, to: blockId, order: shownOrder)
            shownBlockId = blockId
        }
        shownOrder = order
        return edge
    }
}

/// `.push(from:)` with its edge read as the transition runs, not when the view last updated.
struct CardPush: Transition {
    let edge: @MainActor () -> Edge

    func body(content: Content, phase: TransitionPhase) -> some View {
        let from: CGFloat = edge() == .leading ? -1 : 1
        let shift: CGFloat = switch phase {
        case .willAppear: from
        case .didDisappear: -from
        case .identity: 0
        }
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .visualEffect { view, proxy in
                view.offset(x: shift * proxy.size.width)
            }
    }
}

#Preview {
    let start = Date()
    let exercises = ["Bench Press", "Barbell Row", "Squat"].enumerated().map { index, name in
        WorkoutExerciseModel(
            id: "e\(index)", authorId: "a", templateId: "t\(index)", name: name, trackingMode: .weightReps,
            index: index + 1,
            sets: (0..<4).map { set in
                WorkoutSetModel(
                    id: "e\(index)-\(set)", authorId: "a", index: set + 1, reps: 8, weightKg: 80,
                    isWarmup: false, completedAt: set < 2 - index ? start : nil, dateCreated: start
                )
            },
            supersetGroupId: index < 2 ? "g" : nil
        )
    }
    ExerciseStrip(items: ActiveWorkout.stripProgress(for: exercises, currentExerciseId: "e0"), onSelect: { _ in })
}
