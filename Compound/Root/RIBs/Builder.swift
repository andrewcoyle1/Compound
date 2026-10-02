//
//  Buildable.swift
//  Compound
//
//  Created by Andrew Coyle on 04/12/2025.
//

import SwiftUI
@MainActor
protocol Builder {
    func build() -> AnyView
}
