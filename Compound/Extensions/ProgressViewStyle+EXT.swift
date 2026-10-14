//
//  RestLineProgressViewStyle.swift
//  Compound
//
//  The rest line's progress: the bar, with the current value ("Rest: 1:27/1:30") beside it, or
//  under it at accessibility sizes. The bar is the system's own, so a timer-driven progress view
//  keeps the fill the system animates.
//

import SwiftUI

struct RestLineProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        RestLine(configuration: configuration)
    }
}

extension ProgressViewStyle where Self == RestLineProgressViewStyle {
    static var restLine: Self { RestLineProgressViewStyle() }
}

private struct RestLine: View {

    let configuration: ProgressViewStyleConfiguration

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The configuration without its labels: the plain bar, still driven by the timer.
    private var bar: ProgressViewStyleConfiguration {
        var bar = configuration
        bar.label = nil
        bar.currentValueLabel = nil
        return bar
    }

    /// Side by side, or one under the other at accessibility sizes.
    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Spacing.m))
    }

    var body: some View {
        layout {
            ProgressView(bar)
                .progressViewStyle(.linear)
            configuration.currentValueLabel
                .font(.label.weight(.semibold))
                .layoutPriority(1)
        }
        .monospacedDigit()
        .accessibilityElement(children: .combine)
    }
}
