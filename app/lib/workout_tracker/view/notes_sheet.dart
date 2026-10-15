import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';

/// One note the sheet edits.
class const NoteField({
  required final String label,
  required final String initial,
  final String? footer,
});

/// The notes sheet (`WorkoutNotesView`): one field per note, Cancel and
/// [saveLabel]. Returns each field's text, in order, or `null` when
/// cancelled.
Future<List<String>?> showNotesSheet(
  BuildContext context, {
  required String title,
  required String saveLabel,
  required List<NoteField> fields,
}) => showModalBottomSheet<List<String>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.m,
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.trackerCancel),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.rowTitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop([
                    for (final controller in _controllers) controller.text,
                  ]),
                  child: Text(
                    widget.saveLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            for (final (index, field) in widget.fields.indexed)
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
        ),
      ),
    );
  }
}
