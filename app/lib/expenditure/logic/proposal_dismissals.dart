import 'dart:convert';
import 'dart:io';

import 'package:compound_maths/compound_maths.dart' show dismissedProposalKey;

/// The target proposal each account last waved away, so the same card does
/// not come back tomorrow (Swift keeps it in `UserDefaults` under
/// `dismissedTargetProposalKcal.<uid>`). Kept on the device, in a file when
/// given, else in memory for the staging flavor and tests.
class ProposalDismissals {
  /// Reads what the file holds; a file that cannot be read starts empty.
  new({this._file}) {
    final file = _file;
    if (file == null || !file.existsSync()) return;
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is Map<String, Object?>) {
        for (final MapEntry(:key, :value) in json.entries) {
          if (value is num) _kcal[key] = value.toDouble();
        }
      }
    } on FormatException {
      // A file this build cannot read only brings a dismissed card back.
    }
  }

  final File? _file;
  final _kcal = <String, double>{};

  /// The figure [uid] last dismissed, or null.
  double? of(String uid) => _kcal[dismissedProposalKey(uid)];

  /// Remembers that [uid] dismissed a proposal of [kcal].
  void dismiss(String uid, double kcal) {
    _kcal[dismissedProposalKey(uid)] = kcal;
    _save();
  }

  /// Forgets [uid]'s dismissal, once a plan has been accepted.
  void clear(String uid) {
    if (_kcal.remove(dismissedProposalKey(uid)) != null) _save();
  }

  void _save() => _file?.writeAsStringSync(jsonEncode(_kcal), flush: true);
}
