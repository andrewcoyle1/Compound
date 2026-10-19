import 'package:app_ui/app_ui.dart';
import 'package:compound_models/compound_models.dart';

/// An exercise's picture (Swift `ExerciseImageView`): a web address, or a
/// bundled image named by a system exercise, else its initials.
///
/// The bundled pictures are the Swift app's, scaled to 600 px WebP in
/// `assets/exercises/`.
class ExerciseImage extends StatelessWidget {
  new(ExerciseModel exercise, {super.key})
    : name = exercise.name,
      image = exercise.imageUrl;

  /// A session exercise's picture: its `imageName`, a web address or a
  /// bundled image's name.
  const new named({required this.name, required this.image, super.key});

  final String name;
  final String? image;

  @override
  Widget build(BuildContext context) {
    final url = image;
    Widget initials(BuildContext context, Object _, StackTrace? _) =>
        _Initials(name);
    if (url == null || url.isEmpty) return _Initials(name);
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(url, fit: BoxFit.contain, errorBuilder: initials);
    }
    return Image.asset(
      'assets/exercises/$url.webp',
      fit: BoxFit.contain,
      errorBuilder: initials,
    );
  }
}

/// The first letters of [name]'s first two words that start with one,
/// capitalised: "Barbell Bench Press" → "BB", "45° Back Extension" → "BE"
/// (Swift `ExerciseImageView.initials(of:)`).
String initials(String name) => name
    .split(' ')
    .where((word) => word.isNotEmpty)
    .map((word) => word.characters.first)
    .where(_letter.hasMatch)
    .take(2)
    .join()
    .toUpperCase();

final _letter = RegExp(r'^\p{L}$', unicode: true);

class _Initials extends StatelessWidget {
  const new(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letters = initials(name);
    return ColoredBox(
      color: AppColors.tintedSurface(scheme.primary),
      child: Center(
        child: Text(
          letters,
          style: AppTextStyles.sectionTitle.copyWith(color: scheme.primary),
        ),
      ),
    );
  }
}
