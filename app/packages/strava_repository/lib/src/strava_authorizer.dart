import 'package:strava_repository/src/strava_models.dart';

/// The scheme Strava redirects to after its consent page, as the Swift app
/// registers it (`compoundstrava://localhost/exchange_token`). Strava's app
/// settings name `localhost` as the callback domain.
const stravaCallbackScheme = 'compoundstrava';

/// Strava's consent page for [clientId] (Swift `StravaManager.authenticate`).
/// Reading activities is asked for but not required: the athlete may untick
/// it, and then nothing is imported.
Uri stravaAuthorizationUri(String clientId) =>
    Uri.https('www.strava.com', '/oauth/mobile/authorize', {
      'client_id': clientId,
      'redirect_uri': '$stravaCallbackScheme://localhost/exchange_token',
      'response_type': 'code',
      'approval_prompt': 'auto',
      'scope': 'activity:write,activity:read_all',
    });

/// Opens Strava's consent page and returns where it redirected. The OAuth
/// web flow is the platform's: the UI slice implements this with a web
/// authentication session (flutter_web_auth_2 or similar). The staging
/// flavor uses [FakeStravaAuthorizer].
abstract interface class StravaAuthorizer {
  /// Opens [authorizationUri] and completes with the redirect to
  /// [callbackScheme], code and granted scopes in its query. Throws when
  /// the athlete cancels; whatever it throws reaches the caller unchanged.
  Future<Uri> authorize(Uri authorizationUri, String callbackScheme);
}

/// The code from Strava's redirect (Swift `authorizationCode(from:)`).
///
/// Strava lets the athlete untick the upload permission on its consent page
/// and still redirects with a code; connecting then would leave every upload
/// refused, so that is turned away here. Throws a [StravaException]:
/// [StravaFailure.missingAuthCode] or
/// [StravaFailure.missingUploadPermission].
String stravaAuthorizationCode(Uri redirect) {
  final code = redirect.queryParameters['code'];
  if (code == null || code.isEmpty) {
    throw const StravaException(StravaFailure.missingAuthCode);
  }
  // Comma- or space-delimited: Strava documents both.
  final scopes = (redirect.queryParameters['scope'] ?? '').split(
    RegExp('[, ]'),
  );
  if (!scopes.contains('activity:write')) {
    throw const StravaException(StravaFailure.missingUploadPermission);
  }
  return code;
}

/// [StravaAuthorizer] for the staging flavor and tests: answers at once as
/// Strava's consent page does when the athlete agrees to everything.
class FakeStravaAuthorizer implements StravaAuthorizer {
  /// Creates a [FakeStravaAuthorizer] answering with [scope].
  new({this.scope = 'read,activity:write,activity:read_all'});

  /// The scopes the fake grants.
  final String scope;

  /// The pages opened, in order.
  final List<Uri> opened = [];

  @override
  Future<Uri> authorize(Uri authorizationUri, String callbackScheme) async {
    opened.add(authorizationUri);
    return Uri(
      scheme: callbackScheme,
      host: 'localhost',
      path: '/exchange_token',
      queryParameters: {'state': '', 'code': 'staging-code', 'scope': scope},
    );
  }
}
