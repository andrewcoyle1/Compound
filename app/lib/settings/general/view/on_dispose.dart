import 'package:app_ui/app_ui.dart';

/// Calls [onDispose] when it leaves the tree: a screen's `_Disappear`
/// event. The callback is taken when built, so nothing is looked up while
/// the tree is being torn down.
class OnDispose extends StatefulWidget {
  const new({required this.onDispose, required this.child, super.key});

  final VoidCallback onDispose;
  final Widget child;

  @override
  State<OnDispose> createState() => _OnDisposeState();
}

class _OnDisposeState extends State<OnDispose> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
