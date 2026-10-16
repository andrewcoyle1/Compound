/// The production project's workout web pages (the Swift app's
/// `SessionWebLink.baseURL`), for the `sessionWebLink` this flavor will pass
/// once it is wired up. A string only: nothing requests it.
const productionSessionLinkBase = 'https://dialed-c3cb5.web.app/s';

/// The production flavor is not wired up yet: the production Firebase
/// project (`dialed-c3cb5`) is out of bounds until the iOS switch-over
/// (docs/specs/flutter/plan.md, M6). Use the development or staging flavor.
void main() {
  throw UnsupportedError(
    'The production flavor has no Firebase configuration yet. '
    'Run the development or staging flavor instead.',
  );
}
