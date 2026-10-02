//
//  MetricChartType.swift
//  Compound
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Foundation

/// Which QuickCharts chart a metric screen draws, chosen by its `MetricConfiguration`. Named for the
/// metric screens rather than a chart view: it outlived `NewHistoryChart`, which used to own it.
enum MetricChartType {
    case line
    case bar
    case stackedBar
    /// Bars with one series drawn as a line over them, named by
    /// `MetricConfiguration.lineSeriesNames`. The bar series come first.
    case combo
}
