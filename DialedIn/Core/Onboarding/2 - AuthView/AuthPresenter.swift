//
//  AuthPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/10/2025.
//

import SwiftUI

@Observable
@MainActor
class AuthPresenter {
    private let interactor: AuthInteractor
    private let router: AuthRouter

    private(set) var didTriggerLogin: Bool = false
    private(set) var currentAuthTask: Task<Void, Never>?
    
    var currentUser: UserModel? {
        interactor.currentUser
    }

    init(
        interactor: AuthInteractor,
        router: AuthRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func endTask() {
        router.dismissModal()
        currentAuthTask = nil
    }
    
    // MARK: Sign In Apple
    func onSignInApplePressed() {
        // Cancel any existing auth task to prevent race conditions
        currentAuthTask?.cancel()
        
        currentAuthTask = Task {
            // Task Management
            router.showLoadingModal()

            defer {
                endTask()
            }

            // Begin auth
            interactor.trackEvent(event: Event.appleAuthStart)
            do {
                // Get UserAuthInfo
                let (userAuthInfo, isNewUser) = try await interactor.signInApple()
                interactor.trackEvent(event: Event.appleAuthSuccess)

                // Proceed immediately to signing in the user on success
                handleOnAuthSuccess(user: userAuthInfo, isNewUser: isNewUser)
            } catch {
                interactor.trackEvent(event: Event.appleAuthFail(error: error))
                router.showAlert(
                    title: String(localized: "Error Signing in with Apple"),
                    subtitle: String(localized: "Please check your internet connection and try again"),
                    buttons: {
                        AnyView(
                            HStack {
                                Button("Cancel") { }
                                Button("Try Again") {
                                    self.onSignInApplePressed()
                                }
                            }
                        )
                    }
                )
            }
        }
    }

    // MARK: Sign In Google
    func onSignInGooglePressed() {
        // Cancel any existing auth task to prevent race conditions
        currentAuthTask?.cancel()
        
        currentAuthTask = Task {
            // Task Management
            router.showLoadingModal()

            defer {
                endTask()
            }
            
            // Begin auth
            interactor.trackEvent(event: Event.googleAuthStart)
            do {
                let (userAuthInfo, isNewUser) = try await interactor.signInGoogle()
                interactor.trackEvent(event: Event.googleAuthSuccess)

                // Proceed immediately to signing in the user on success
                handleOnAuthSuccess(user: userAuthInfo, isNewUser: isNewUser)
            } catch {
                interactor.trackEvent(event: Event.googleAuthFail(error: error))
                router.showAlert(
                    title: String(localized: "Error Signing in with Google"),
                    subtitle: String(localized: "Please check your internet connection and try again"),
                    buttons: {
                        AnyView(
                            HStack {
                                Button("Cancel") { }
                                Button("Try Again") {
                                    self.onSignInGooglePressed()
                                }
                            }
                        )
                    }
                )
            }
        }
    }
    
    // MARK: User Log In
    func handleOnAuthSuccess(user: UserAuthInfo, isNewUser: Bool) {
        // Cancel any existing auth task to prevent conflicts
        currentAuthTask?.cancel()
        
        currentAuthTask = Task {
            
            didTriggerLogin = true
            // Task Management
            router.showLoadingModal()

            defer {
                endTask()
            }
            
            // Begin user login
            interactor.trackEvent(event: Event.userLoginStart)
            do {
                // Log in user (anonymous account migration and cleanup handled inside logIn)
                try await interactor.logIn(user: user, isNewUser: isNewUser)
                interactor.trackEvent(event: Event.userLoginSuccess)
                
                // The profile lands when the sync engine's listener next emits, not when `logIn`
                // returns, so this can lose the race. Returning silently left the user on the auth
                // screen after a *successful* login, with a Success event and no destination — the
                // one shape analytics could not tell from a user who simply stopped here.
                guard let user = currentUser else {
                    interactor.trackEvent(event: Event.userLoginNoCurrentUser)
                    return
                }
                // The subscription gate comes first, ahead of every other destination. This is a
                // premium app: a user without a subscription is shown the subscription page no
                // matter how far through onboarding they are. It used to sit after the returning
                // user branch below, which meant anyone who had finished onboarding and then
                // lapsed went straight into the app for free on every sign-in.
                if interactor.isPremium == false {
                    interactor.trackEvent(event: Event.paywallShownAfterLogin)
                    router.showSubscriptionView()
                } else if !isNewUser && user.didCompleteOnboarding {
                    // Returning subscriber with a full account — go straight to core
                    router.switchToCoreModule()
                } else if user.inferredOnboardingStep != .complete {
                    // Premium but onboarding not finished — resume from inferred step
                    handleNavigation()
                } else {
                    // Premium + onboarding complete (e.g. restored purchase on new device)
                    router.switchToCoreModule()
                }
            } catch {
                interactor.trackEvent(event: Event.userLoginFail(error: error))
                router.showAlert(
                    title: String(localized: "Error Logging In"),
                    subtitle: String(localized: "Please check your internet connection and try again."),
                    buttons: {
                        AnyView(
                            HStack {
                                Button {
                                    self.didTriggerLogin = false
                                } label: {
                                    Text("Cancel")
                                }
                                Button("Try Again") {
                                    self.handleOnAuthSuccess(user: user, isNewUser: isNewUser)
                                }
                            }
                        )
                    }
                )
            }
        }
    }
    
    // MARK: Handle Navigation
    func handleNavigation() {
        // Navigate based on user's inferred onboarding step
        if let currentUser = interactor.currentUser {
            let step = currentUser.inferredOnboardingStep
            interactor.trackEvent(event: Event.navigate)
            route(to: step)
        }
    }

    private func route(to step: OnboardingStep) {
        router.routeToOnboardingStep(step, onComplete: handleNavigation)
    }
            
    // MARK: Cleanup Tasks
    func cleanUp() {
        currentAuthTask?.cancel()
        currentAuthTask = nil
        
        router.dismissModal()
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    // MARK: Events
    enum Event: LoggableEvent {
        case appleAuthStart
        case appleAuthSuccess
        case appleAuthFail(error: Error)

        case googleAuthStart
        case googleAuthSuccess
        case googleAuthFail(error: Error)
        
        case userLoginStart
        case userLoginSuccess
        case userLoginFail(error: Error)
        case userLoginNoCurrentUser

        case navigate
        case paywallShownAfterLogin

        var eventName: String {
            switch self {
            case .appleAuthStart:    return "Auth_AppleAuth_Start"
            case .appleAuthSuccess:  return "Auth_AppleAuth_Success"
            case .appleAuthFail:     return "Auth_AppleAuth_Fail"
            case .googleAuthStart:   return "Auth_GoogleAuth_Start"
            case .googleAuthSuccess: return "Auth_GoogleAuth_Success"
            case .googleAuthFail:    return "Auth_GoogleAuth_Fail"
            case .userLoginStart:    return "Auth_UserLogin_Start"
            case .userLoginSuccess:  return "Auth_UserLogin_Success"
            case .userLoginFail:     return "Auth_UserLogin_Fail"
            case .userLoginNoCurrentUser: return "Auth_UserLogin_NoCurrentUser"
            case .navigate:          return "Auth_Navigate"
            case .paywallShownAfterLogin: return "Auth_PaywallShownAfterLogin"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .appleAuthFail(error: let error), .googleAuthFail(error: let error), .userLoginFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .appleAuthFail, .googleAuthFail, .userLoginFail, .userLoginNoCurrentUser:
                return LogType.severe
            case .navigate, .paywallShownAfterLogin:
                return LogType.info
            default:
                return LogType.analytic

            }
        }
    }
}
