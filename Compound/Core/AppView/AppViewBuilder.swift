//
//  AppViewBuilder.swift
//  Compound
//
//  Created by Andrew Coyle on 13/08/2025.
//

import SwiftUI

struct AppViewBuilder<TabBarView: View, OnboardingView: View>: View {
    
    var activeModuleId: String = Constants.onboardingModuleId
    var tabBarView: () -> TabBarView
    var onboardingView: () -> OnboardingView

    var body: some View {
        ZStack {
            if activeModuleId == Constants.tabBarModuleId {
                tabBarView()
                    .transition(.move(edge: .trailing))
            } else {
                onboardingView()
                    .transition(.move(edge: .leading))
            } 
        }
        .animation(.default, value: activeModuleId)
    }
}

private func onTabBarTapped(_ activeTab: Binding<String>) {
    if activeTab.wrappedValue == Constants.onboardingModuleId {
        activeTab.wrappedValue = Constants.tabBarModuleId
    } else {
        activeTab.wrappedValue = Constants.onboardingModuleId
    }
}

#Preview {
    @Previewable @State var activeTab: String = Constants.onboardingModuleId
    
    AppViewBuilder(
        activeModuleId: activeTab,
        tabBarView: {
            ZStack {
                Color.red.ignoresSafeArea()
                Text("Tab Bar View")
            }
        },
        onboardingView: {
            ZStack {
                Color.blue.ignoresSafeArea()
                Text("Onboarding View")
            }
        }
    )
    .onTapGesture {
        onTabBarTapped($activeTab)
    }
}
