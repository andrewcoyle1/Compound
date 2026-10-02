//
//  QuickCharts+Alias.swift
//  Compound
//
//  Created by Andrew Coyle on 19/09/2026.
//

import QuickCharts
import SwiftUI

typealias TimeSeries = QuickCharts.TimeSeries
typealias TimeSeriesDatapoint = QuickCharts.TimeSeriesDatapoint
typealias TimeSeriesBandDatapoint = QuickCharts.TimeSeriesBandDatapoint
typealias ChartConfiguration = QuickCharts.ChartConfiguration
typealias ChartScreen<Chart: View, Accessories: View, MoreRows: View, Sections: View> =
    QuickCharts.ChartScreen<Chart, Accessories, MoreRows, Sections>
typealias ChartValueRow = QuickCharts.ChartValueRow
typealias ChartHighlight = QuickCharts.ChartHighlight
typealias LineChart = QuickCharts.LineChart
typealias BarChart = QuickCharts.BarChart
typealias StackedBarChart = QuickCharts.StackedBarChart
typealias ComboChart = QuickCharts.ComboChart
typealias ContributionChart = QuickCharts.ContributionChart
typealias ContributionGrid = QuickCharts.ContributionGrid
typealias ContributionGridView = QuickCharts.ContributionGridView
typealias ContributionLegend = QuickCharts.ContributionLegend
typealias ContributionStyle = QuickCharts.ContributionStyle
typealias ContributionLayout = QuickCharts.ContributionLayout
typealias ContributionCell = QuickCharts.ContributionCell
typealias ChartThumbnail = QuickCharts.ChartThumbnail
typealias ProgressThumbnail = QuickCharts.ProgressThumbnail
