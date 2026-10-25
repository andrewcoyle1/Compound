import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';

/// One note the sheet edits.
class const NoteField({
  required final String label,
  required final String initial,
  final String? footer,

  /// Last session's note, shown above the field: "Last time: …".
  final String? hint,
});

/// The notes sheet (`WorkoutNotesView`): one field per note, with close at
/// the leading edge and [saveLabel]'s confirm at the trailing edge. Returns
/// each field's text, in order, or `null` when closed.
Future<List<String>?> showNotesSheet(
  BuildContext context, {
  required String title,
  required String saveLabel,
  required List<NoteField> fields,
}) => showAppSheet<List<String>>(
  context: context,
  size: AppSheetSize.full,
  builder: (_) =>
      _NotesSheet(title: title, saveLabel: saveLabel, fields: fields),
);

class _NotesSheet extends StatefulWidget {
  const new({
    required this.title,
    required this.saveLabel,
    required this.fields,
  });

  final String title;
  final String saveLabel;
  final List<NoteField> fields;

  @override
  State<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<_NotesSheet> {
  late final List<TextEditingController> _controllers = [
    for (final field in widget.fields)
      TextEditingController(text: field.initial),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppToolbarButton.close(
          semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
        title: Text(widget.title),
        actions: [
          AppToolbarButton.confirm(
            semanticLabel: widget.saveLabel,
            onPressed: () => Navigator.of(context)
                .pop([for (final controller in _controllers) controller.text]),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.m,
          children: [
            for (final (index, field) in widget.fields.indexed) ...[
              if (field.hint case final hint?)
                Text(
                  l10n.trackerLastTimeNote(hint),
                  style: AppTextStyles.rowDetail.secondary(context),
                ),
              TextField(
                controller: _controllers[index],
                autofocus: index == 0,
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: field.label,
                  helperText: field.footer,
                  helperMaxLines: 3,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: const OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.m),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
