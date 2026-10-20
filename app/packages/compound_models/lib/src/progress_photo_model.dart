import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';

/// The pose of a progress photo (Swift `ProgressPhotoModel.Pose`).
enum ProgressPhotoPose implements FirestoreEnum {
  /// `front`.
  front('front'),

  /// `side`.
  side('side'),

  /// `back`.
  back('back');

  new(this.value);

  @override
  final String value;
}

/// Field names of `users/{uid}/progress_photos/{id}`, exactly as the Swift
/// `CodingKeys` spell them.
abstract final class ProgressPhotoModelKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `date`.
  static const date = 'date';

  /// `pose`.
  static const pose = 'pose';

  /// `storage_path`.
  static const storagePath = 'storage_path';

  /// `image_url`.
  static const imageUrl = 'image_url';

  /// `weight_kg`.
  static const weightKg = 'weight_kg';

  /// `note`.
  static const note = 'note';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    date,
    pose,
    storagePath,
    imageUrl,
    weightKg,
    note,
  ];
}

/// One progress photo at `users/{uid}/progress_photos/{id}` (Swift
/// `ProgressPhotoModel`), its JPEG in Firebase Storage at [storagePath].
/// Owner-only in both places.
class const ProgressPhotoModel({
  /// The photo's id, and the document id.
  required final String id,

  /// The user it belongs to.
  required final String authorId,

  /// When it was taken.
  required final DateTime date,

  /// Front, side or back.
  required final ProgressPhotoPose pose,

  /// `users/{uid}/progress_photos/{id}.jpg` in Storage: [storagePathFor].
  /// The rules refuse any other.
  required final String storagePath,

  /// The download URL the upload returned (in staging, a `data:` URI or a
  /// bundled asset).
  final String? imageUrl,

  /// The latest scale weight when it was taken.
  final double? weightKg,

  /// A note.
  final String? note,
}) {
  /// Creates a [ProgressPhotoModel].
  this;

  /// Decodes as Swift's synthesized decoder does, strictly: a missing
  /// required field, a wrong type or an unknown pose throws.
  factory fromFirestore(Map<String, Object?> data) => ProgressPhotoModel(
    id: data[ProgressPhotoModelKeys.id]! as String,
    authorId: data[ProgressPhotoModelKeys.authorId]! as String,
    date: data[ProgressPhotoModelKeys.date]! as DateTime,
    pose: enumFromValue(
      ProgressPhotoPose.values,
      data[ProgressPhotoModelKeys.pose]! as String,
    ),
    storagePath: data[ProgressPhotoModelKeys.storagePath]! as String,
    imageUrl: data[ProgressPhotoModelKeys.imageUrl] as String?,
    weightKg: readOptionalDouble(data[ProgressPhotoModelKeys.weightKg]),
    note: data[ProgressPhotoModelKeys.note] as String?,
  );

  /// Where [uid]'s photo [id] is kept in Storage, as Swift's
  /// `ProgressPhotoModel.storagePath(userId:id:)`.
  static String storagePathFor(String uid, String id) =>
      'users/$uid/progress_photos/$id.jpg';

  /// The Firestore-shaped map Swift writes: a null field is left out.
  Map<String, Object?> toFirestore() => {
    ProgressPhotoModelKeys.id: id,
    ProgressPhotoModelKeys.authorId: authorId,
    ProgressPhotoModelKeys.date: date,
    ProgressPhotoModelKeys.pose: pose.value,
    ProgressPhotoModelKeys.storagePath: storagePath,
    ProgressPhotoModelKeys.imageUrl: ?imageUrl,
    ProgressPhotoModelKeys.weightKg: ?weightKg,
    ProgressPhotoModelKeys.note: ?note,
  };
}
