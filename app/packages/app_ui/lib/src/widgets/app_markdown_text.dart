import 'package:app_ui/app_ui.dart';
import 'package:markdown/markdown.dart' as md;

/// Light markdown, as an AI answer is written, set as one selectable run of
/// text in [style]: headings, bulleted and numbered lists, bold, italic,
/// struck-through and inline code. A link shows as its text and opens
/// nothing; anything else shows as its text.
class AppMarkdownText extends StatelessWidget {
  /// [data] in [style], [AppTextStyles.rowTitle] by default.
  const new(this.data, {this.style, super.key});

  /// The markdown.
  final String data;

  /// The body's style; headings are [AppTextStyles.sectionTitle].
  final TextStyle? style;

  /// [data] as plain text, for a screen reader: no markers, lists bulleted.
  static String plainText(String data) =>
      TextSpan(children: _spans(data, const TextStyle())).toPlainText();

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? AppTextStyles.rowTitle;
    return SelectableText.rich(
      TextSpan(children: _spans(data, style)),
      style: style,
    );
  }
}

List<InlineSpan> _spans(String data, TextStyle style) {
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  return (_Spans(style)..visitAll(document.parseLines(data.split('\n')))).spans;
}

/// Walks the parsed markdown into spans, with a blank line between blocks
/// and a line break between list items.
class _Spans {
  new(this.base);

  final TextStyle base;
  final spans = <InlineSpan>[];
  String _gap = '';

  void visitAll(List<md.Node> nodes, [TextStyle? style, int depth = 0]) {
    for (final node in nodes) {
      _visit(node, style ?? base, depth);
    }
  }

  /// Separates what comes next from what came before by at least [gap].
  void _break(String gap) {
    if (spans.isNotEmpty && gap.length > _gap.length) _gap = gap;
  }

  void _text(String text, TextStyle style) {
    if (_gap.isNotEmpty) spans.add(TextSpan(text: _gap));
    _gap = '';
    spans.add(TextSpan(text: text, style: style));
  }

  void _visit(md.Node node, TextStyle style, int depth) {
    if (node is md.Text) return _text(node.text, style);
    if (node is! md.Element) return;
    final children = node.children ?? const <md.Node>[];
    switch (node.tag) {
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        _break('\n\n');
        visitAll(children, AppTextStyles.sectionTitle, depth);
      case 'ul' || 'ol':
        _break(depth == 0 ? '\n\n' : '\n');
        var number = int.tryParse(node.attributes['start'] ?? '') ?? 1;
        for (final item in children) {
          _break('\n');
          final marker = node.tag == 'ol' ? '${number++}.' : '•';
          _text('${'    ' * depth}$marker ', style);
          visitAll(
            [
              for (final child in (item as md.Element).children ?? <md.Node>[])
                // A loose list's paragraphs stay on the item's line.
                if (child is md.Element && child.tag == 'p')
                  ...?child.children
                else
                  child,
            ],
            style,
            depth + 1,
          );
        }
        _break('\n\n');
      case 'strong':
        visitAll(children, AppTextStyles.emphasized(style), depth);
      case 'em':
        visitAll(children, style.copyWith(fontStyle: FontStyle.italic), depth);
      case 'del':
        visitAll(
          children,
          style.copyWith(decoration: TextDecoration.lineThrough),
          depth,
        );
      case 'code':
        // Android's monospace; iOS knows it as Menlo.
        _text(
          node.textContent,
          style.copyWith(
            fontFamily: 'monospace',
            fontFamilyFallback: const ['Menlo', 'Courier'],
          ),
        );
      case 'br':
        _text('\n', style);
      case 'hr':
        _break('\n\n');
      case 'p' || 'pre' || 'blockquote' || 'table':
        _break('\n\n');
        visitAll(children, style, depth);
        _break('\n\n');
      default:
        visitAll(children, style, depth);
    }
  }
}
