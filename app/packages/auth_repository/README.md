# auth_repository

Signs users in and out of Compound.

- `FirebaseAuthRepository`: Firebase Auth with Google (google_sign_in 7), Apple
  (`signInWithProvider`) and anonymous accounts. Signing in from an anonymous account links the
  new provider to it, so the uid and its data are kept; if the provider already belongs to another
  account, that account is signed in instead (as SwiftfulAuthenticating does in the Swift app).
- `InMemoryAuthRepository`: no backend, for the staging flavor and widget tests.

Run the tests with `very_good test --coverage --min-coverage 100`.
