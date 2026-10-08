//
//  ExerciseStrip.swift
//  Compound
//
//  The workout as a row of thumbnails over the card, one per block, each underlined with its
//  progress. A tap opens that block on the card. Behind `WorkoutSettings.showsExerciseStrip`,
//  which also slides the card in from the side of the strip it was picked from.
//

import SwiftUI
import UniformTypeIdentifiers

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
    /// A block dropped on another's place, or moved a step by its menu or an accessibility action:
    /// its id and its new index among the other blocks.
    var onMove: (String, Int) -> Void = { _, _ in }
    /// The strip's last item: Add Exercise, standing in for the list's row while the strip is up.
    var onAddExercise: () -> Void = {}

    @ScaledMetric(relativeTo: .body) private var side = ControlSize.thumbnail
    /// The thumbnail a drag is held over, ringed as the drop's target; `Self.addTarget` for Add.
    @State private var targetedId: String?
    private static let addTarget = "add"

    private var currentId: String? { items.first(where: \.isCurrent)?.id }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: Spacing.s) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item.id)
                        } label: {
                            thumbnail(item, targeted: targetedId == item.id)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { stripMenu(item) }
                        // Hold still for the menu, move to drag: the system shares one long press.
                        .draggable(StripDragItem(blockId: item.id))
                        .dropDestination(for: StripDragItem.self) { dropped, _ in
                            drop(dropped, at: items.firstIndex { $0.id == item.id })
                        } isTargeted: { targeted in
                            target(item.id, targeted)
                        }
                        .id(item.id)
                        .accessibilityLabel(item.names.formatted(.list(type: .and)))
                        .accessibilityValue(accessibilityValue(item))
                        .accessibilityAddTraits(item.isCurrent ? .isSelected : [])
                        .accessibilityHint("Opens this exercise")
                        .accessibilityActions { stripActions(item) }
                    }
                    Button(action: onAddExercise) {
                        addThumbnail(targeted: targetedId == Self.addTarget)
                    }
                    .buttonStyle(.plain)
                    // Dropped past the last thumbnail: the block goes to the end.
                    .dropDestination(for: StripDragItem.self) { dropped, _ in
                        drop(dropped, at: items.count - 1)
                    } isTargeted: { targeted in
                        target(Self.addTarget, targeted)
                    }
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

    // MARK: - Reordering

    /// The dropped block takes the place of the thumbnail it landed on (`index` among the other
    /// blocks), as a row dropped in a list does. True when a block landed; the system springs
    /// anything else back.
    private func drop(_ dropped: [StripDragItem], at index: Int?) -> Bool {
        targetedId = nil
        guard let id = dropped.first?.blockId, let index else { return false }
        withReducedMotionAnimation(.standard) { onMove(id, index) }
        return true
    }

    private func target(_ id: String, _ targeted: Bool) {
        if targeted {
            targetedId = id
        } else if targetedId == id {
            targetedId = nil
        }
    }

    private func position(of item: ActiveWorkout.StripItem) -> Int? {
        items.firstIndex { $0.id == item.id }
    }

    /// Do Next and Do Later as before, then a step either way: the visible equivalent of the
    /// drag, and what Switch Control and Voice Control reach.
    @ViewBuilder
    private func stripMenu(_ item: ActiveWorkout.StripItem) -> some View {
        if !item.isCurrent && !item.isComplete {
            Button { onDoNext(item.id) } label: { Label("Do Next", systemImage: Symbol.doNext) }
            Button { onDoLater(item.id) } label: { Label("Do Later", systemImage: Symbol.doLater) }
        }
        if let index = position(of: item), index > 0 {
            Button { step(item.id, to: index - 1) } label: { Label("Move Earlier", systemImage: Symbol.moveEarlier) }
        }
        if let index = position(of: item), index < items.count - 1 {
            Button { step(item.id, to: index + 1) } label: { Label("Move Later", systemImage: Symbol.moveLater) }
        }
    }

    /// The same four for VoiceOver's actions rotor, which takes no symbols.
    @ViewBuilder
    private func stripActions(_ item: ActiveWorkout.StripItem) -> some View {
        if !item.isCurrent && !item.isComplete {
            Button("Do Next") { onDoNext(item.id) }
            Button("Do Later") { onDoLater(item.id) }
        }
        if let index = position(of: item), index > 0 {
            Button("Move Earlier") { step(item.id, to: index - 1) }
        }
        if let index = position(of: item), index < items.count - 1 {
            Button("Move Later") { step(item.id, to: index + 1) }
        }
    }

    private func step(_ id: String, to index: Int) {
        withReducedMotionAnimation(.standard) { onMove(id, index) }
    }

    /// A superset's members sit side by side under one ring and one progress bar: the strip
    /// shows it as the one block it is on the card. Ringed when current, and while a drag is
    /// held over it as the place the block would take.
    private func thumbnail(_ item: ActiveWorkout.StripItem, targeted: Bool) -> some View {
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
                if item.isCurrent || targeted {
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

    /// A plus in a thumbnail's frame, with the bar's space left under it so it lines up. Ringed
    /// while a drag is held over it: the block would go to the end.
    private func addThumbnail(targeted: Bool) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: Symbol.add)
                .iconSize(.medium)
                .foregroundStyle(.tint)
                .frame(width: side, height: side)
                .background(Color.surface)
                .clipShape(.rect(cornerRadius: Radius.s, style: .continuous))
                .overlay {
                    if targeted {
                        RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                            .strokeBorder(.tint, lineWidth: 2)
                    }
                }
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

// MARK: - The drag

/// What a thumbnail carries while dragged: its block. An app-owned type, so no text field or
/// other app accepts it and no foreign drag rings the strip.
private struct StripDragItem: Codable, Sendable, Transferable {
    let blockId: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .stripBlock)
    }
}

private extension UTType {
    static let stripBlock = UTType(exportedAs: "com.andrewcoyle.compound.strip-block")
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
