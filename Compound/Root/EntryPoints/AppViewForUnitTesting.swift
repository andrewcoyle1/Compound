//
//  AppViewForUnitTesting.swift
//  Compound
//
//  Created by Andrew Coyle on 30/10/2025.
//

import SwiftUI

struct AppViewForUnitTesting: App {
    
    @State var isLoading = false
    
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("Testing")
                HStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 10)
                        .scaleEffect(isLoading ? 1.5 : 0.5)
                        .animation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true), value: isLoading)
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 10)
                        .scaleEffect(isLoading ? 1.5 : 0.5)
                        .animation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true).delay(0.1), value: isLoading)
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 10)
                        .scaleEffect(isLoading ? 1.5 : 0.5)
                        .animation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true).delay(0.2), value: isLoading)
                }
            }
            .onAppear {
                isLoading = true
            }
        }
    }
}
