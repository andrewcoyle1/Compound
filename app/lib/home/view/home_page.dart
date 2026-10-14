import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// Placeholder until Today arrives (M2): who is signed in, and sign out.
class HomePage extends StatelessWidget {
  const new({super.key});

  static const path = '/';
  static const name = 'home';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AppBloc>().state;
    final user = state is AppAuthenticated ? state.user : null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            if (user != null) ...[
              SelectableText(l10n.homeUserId(user.uid)),
              Text(
                user.isAnonymous
                    ? l10n.homeAnonymous
                    : l10n.homeEmail(user.email ?? '–'),
              ),
            ],
            FilledButton(
              onPressed: () =>
                  context.read<AppBloc>().add(const AppSignOutPressed()),
              child: Text(l10n.signOutButton),
            ),
          ],
        ),
      ),
    );
  }
}
