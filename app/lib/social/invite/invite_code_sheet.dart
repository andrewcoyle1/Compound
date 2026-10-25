import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';

/// Asks for the code from a friend's invite link, for a link opened on
/// another device than the one with the app (`InviteCodeSheet`). Pops with
/// the code typed, or null when closed.
Future<String?> showInviteCodeSheet(BuildContext context) =>
    showAppSheet<String>(
      context: context,
      size: AppSheetSize.compact,
      builder: (_) => const InviteCodeSheet(),
    );

class InviteCodeSheet extends StatefulWidget {
  const new({super.key});

  @override
  State<InviteCodeSheet> createState() => _InviteCodeSheetState();
}

class _InviteCodeSheetState extends State<InviteCodeSheet> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool get _canJoin => _code.text.trim().isNotEmpty;

  void _join() {
    if (_canJoin) Navigator.of(context).pop(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppToolbarButton.close(semanticLabel: l10n.socialClose),
        title: Text(l10n.inviteEnterCode),
        actions: [
          AppToolbarButton.confirm(
            semanticLabel: l10n.inviteJoin,
            onPressed: _canJoin ? _join : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            footer: l10n.inviteCodeFooter,
            children: [
              AppTextFieldRow(
                label: l10n.inviteCode,
                controller: _code,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.join,
                autocorrect: false,
                onSubmitted: (_) => _join(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
