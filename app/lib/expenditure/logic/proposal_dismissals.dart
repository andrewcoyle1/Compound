import 'package:compound_maths/compound_maths.dart' show dismissedProposalKey;
import 'package:device_store/device_store.dart';

/// The target proposal each account last waved away, so the same card does
/// not come back tomorrow. Kept on the device as Swift keeps it in
/// `UserDefaults`, a double under `dismissedTargetProposalKcal.<uid>`.
class ProposalDismissals {
  /// Keeps them in [store]; in memory when left out.
  new({DeviceStore? store}) : _store = store ?? InMemoryDeviceStore();

  final DeviceStore _store;

  /// The figure [uid] last dismissed, or null.
  double? of(String uid) => _store.getDouble(dismissedProposalKey(uid));

  /// Remembers that [uid] dismissed a proposal of [kcal].
  void dismiss(String uid, double kcal) =>
      _store.setDouble(dismissedProposalKey(uid), kcal);

  /// Forgets [uid]'s dismissal, once a plan has been accepted.
  void clear(String uid) => _store.remove(dismissedProposalKey(uid));
}
