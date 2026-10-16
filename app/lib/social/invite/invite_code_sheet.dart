import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';

/// Asks for the code from a friend's invite link, for a link opened on
/// another device than the one with the app (`InviteCodeSheet`). Pops with
/// the code typed, or null when closed.
Future<String?> showInviteCodeSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l10n.socialClose,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(AppSymbols.close),
              ),
              Expanded(
                child: Text(
                  l10n.inviteEnterCode,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              TextButton(
                onPressed: _canJoin ? _join : null,
                child: Text(
                  l10n.inviteJoin,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: AppSection(
              footer: l10n.inviteCodeFooter,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  child: TextField(
                    controller: _code,
                    autofocus: true,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.join,
                    decoration: InputDecoration(
                      hintText: l10n.inviteCode,
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onSubmitted: (_) => _join(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
