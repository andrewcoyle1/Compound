//
//  SignInCancellation.swift
//  Compound
//
//  Closing a sign-in sheet is a choice, not a failure. Deleting an account asks for Apple or
//  Google sign-in again, and connecting Strava opens a web sign-in; closing either used to raise
//  an alert that read as something having gone wrong.
//

import AuthenticationServices
import GoogleSignIn

enum SignInCancellation {

    /// Whether the person closed the sign-in sheet rather than it failing.
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let nsError = error as NSError
        switch nsError.domain {
        case ASAuthorizationError.errorDomain:
            return nsError.code == ASAuthorizationError.canceled.rawValue
        case ASWebAuthenticationSessionError.errorDomain:
            return nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
        case kGIDSignInErrorDomain:
            return nsError.code == GIDSignInError.Code.canceled.rawValue
        default:
            return false
        }
    }
}
