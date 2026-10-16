import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:strava_repository/strava_repository.dart';

/// The athlete closed Strava's consent page: a choice, not a failed
/// connection (Swift `SignInCancellation`).
class StravaAuthorizationCancelled implements Exception {
  /// Creates a [StravaAuthorizationCancelled].
  const new();
}

/// [StravaAuthorizer] on the platform's web authentication session
/// (`ASWebAuthenticationSession` on iOS, a Custom Tab on Android), as Swift's
/// `StravaManager.authenticate`. Android hands the `compoundstrava`
/// redirect back through the callback activity in `AndroidManifest.xml`.
class WebStravaAuthorizer implements StravaAuthorizer {
  /// Creates a [WebStravaAuthorizer].
  const new();

  @override
  Future<Uri> authorize(Uri authorizationUri, String callbackScheme) async {
    try {
      return Uri.parse(
        await FlutterWebAuth2.authenticate(
          url: authorizationUri.toString(),
          callbackUrlScheme: callbackScheme,
        ),
      );
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') throw const StravaAuthorizationCancelled();
      rethrow;
    }
  }
}
