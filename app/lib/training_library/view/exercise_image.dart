import 'package:app_ui/app_ui.dart';
import 'package:compound_models/compound_models.dart';

/// An exercise's picture (Swift `ExerciseImageView`): a web address, or a
/// bundled image named by a system exercise, else its initials.
///
/// The bundled pictures are the Swift app's, scaled to 600 px WebP in
/// `assets/exercises/`.
class ExerciseImage extends StatelessWidget {
  const new(this.exercise, {super.key});

  final ExerciseModel exercise;

  @override
  Widget build(BuildContext context) {
    final url = exercise.imageUrl;
    Widget initials(BuildContext context, Object _, StackTrace? _) =>
        _Initials(exercise.name);
    if (url == null || url.isEmpty) return _Initials(exercise.name);
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

class _Initials extends StatelessWidget {
  const new(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letters = name
        .split(' ')
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return ColoredBox(
      color: AppColors.tintedSurface(scheme.primary),
      child: Center(
        child: Text(
          letters,
          style: AppTextStyles.rowDetail.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
