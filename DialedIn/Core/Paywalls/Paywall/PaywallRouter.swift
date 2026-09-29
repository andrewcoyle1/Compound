import SwiftUI

@MainActor
protocol PaywallRouter: OnboardingStepRouter, PaywallExitsRouter { }

extension CoreRouter: PaywallRouter { }
