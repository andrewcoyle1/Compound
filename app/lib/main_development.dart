import 'package:compound/app/app.dart';
import 'package:compound/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
