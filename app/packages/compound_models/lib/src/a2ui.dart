/// The four A2UI v0.9 server-to-client messages, and the surface they
/// build: the format of the coach's generative UI blocks. Our own small
/// reader rather than the `a2ui_core` package, which is pre-1.0, changes
/// every few weeks and brings a signals runtime and a schema builder for
/// what is a few dozen lines here.
library;

/// The protocol version every message carries.
const a2uiVersion = 'v0.9';

/// One A2UI message, for the surface [surfaceId].
sealed class A2uiMessage {
  const new(this.surfaceId);

  /// Reads one message: `{"version": "v0.9", <one of the four>}`.
  ///
  /// Throws a [FormatException] for anything else.
  factory parse(Object? json) => switch (json) {
    {
      'version': a2uiVersion,
      'createSurface': {
        'surfaceId': final String surfaceId,
        'catalogId': final String catalogId,
      },
    } =>
      A2uiCreateSurface(surfaceId, catalogId),
    {
      'version': a2uiVersion,
      'updateComponents': {
        'surfaceId': final String surfaceId,
        'components': final List<Object?> components,
      },
    } =>
      A2uiUpdateComponents(surfaceId, [
        for (final component in components) A2uiComponent.parse(component),
      ]),
    {
      'version': a2uiVersion,
      'updateDataModel':
          {'surfaceId': final String surfaceId, 'path': final String path} &&
          final Map<Object?, Object?> update,
    } =>
      A2uiUpdateDataModel(surfaceId, path, update['value']),
    {
      'version': a2uiVersion,
      'deleteSurface': {'surfaceId': final String surfaceId},
    } =>
      A2uiDeleteSurface(surfaceId),
    _ => throw FormatException('Not an A2UI $a2uiVersion message', json),
  };

  /// The surface it is for.
  final String surfaceId;
}

/// `createSurface`: a new surface drawn from [catalogId]'s components.
final class A2uiCreateSurface extends A2uiMessage {
  /// Creates an [A2uiCreateSurface].
  const new(super.surfaceId, this.catalogId);

  /// The catalog its components come from.
  final String catalogId;
}

/// `updateComponents`: components added, or replaced by id.
final class A2uiUpdateComponents extends A2uiMessage {
  /// Creates an [A2uiUpdateComponents].
  const new(super.surfaceId, this.components);

  /// The components.
  final List<A2uiComponent> components;
}

/// `updateDataModel`: [value] put at [path] in the data model; `/` replaces
/// all of it.
final class A2uiUpdateDataModel extends A2uiMessage {
  /// Creates an [A2uiUpdateDataModel].
  const new(super.surfaceId, this.path, this.value);

  /// A JSON pointer.
  final String path;

  /// The value, as raw JSON.
  final Object? value;
}

/// `deleteSurface`: the surface is gone.
final class A2uiDeleteSurface extends A2uiMessage {
  /// Creates an [A2uiDeleteSurface].
  const new(super.surfaceId);
}

/// One component of a surface: `{"id", "component", …props}`.
final class A2uiComponent {
  /// Creates an [A2uiComponent].
  const new({required this.id, required this.component, this.props = const {}});

  /// Reads one component. Throws a [FormatException] without an id or a
  /// component name.
  factory parse(Object? json) => switch (json) {
    {'id': final String id, 'component': final String component} &&
        final Map<Object?, Object?> map =>
      A2uiComponent(
        id: id,
        component: component,
        props: {
          for (final MapEntry(:key, :value) in map.entries)
            if (key != 'id' && key != 'component') '$key': value,
        },
      ),
    _ => throw FormatException('Not an A2UI component', json),
  };

  /// Its id; the surface draws `root`.
  final String id;

  /// Its name in the catalog, such as `TrendChart`.
  final String component;

  /// Everything else: literal values, or bindings `{"path": "/…"}`.
  final Map<String, Object?> props;
}

/// The one surface a list of messages builds: its catalog, components and
/// data model.
final class A2uiSurface {
  new _(this.surfaceId, this.catalogId);

  /// Applies [messages] in order. The first must create the surface, and
  /// every one must be for it; a surface they delete has nothing to show.
  ///
  /// Throws a [FormatException] for an invalid message or sequence.
  factory fromMessages(List<Object?> messages) {
    final parsed = [for (final message in messages) A2uiMessage.parse(message)];
    final first = parsed.firstOrNull;
    if (first is! A2uiCreateSurface) {
      throw FormatException('A surface starts with createSurface', messages);
    }
    final surface = A2uiSurface._(first.surfaceId, first.catalogId);
    for (final message in parsed.skip(1)) {
      if (message.surfaceId != surface.surfaceId) {
        throw FormatException('Another surface', message.surfaceId);
      }
      switch (message) {
        case A2uiUpdateComponents(:final components):
          for (final component in components) {
            surface.components[component.id] = component;
          }
        case A2uiUpdateDataModel(:final path, :final value):
          surface._data = _write(surface._data, _segments(path), value);
        case A2uiCreateSurface() || A2uiDeleteSurface():
          throw FormatException('Created twice, or deleted', message);
      }
    }
    return surface;
  }

  /// The surface's id.
  final String surfaceId;

  /// The catalog its components come from.
  final String catalogId;

  /// Its components, by id.
  final Map<String, A2uiComponent> components = {};

  Object? _data;

  /// The component drawn first, if any.
  A2uiComponent? get root => components['root'];

  /// The data model's value at the JSON pointer [path] (`/`, or a key or
  /// list index per segment), or null where there is none.
  Object? read(String path) {
    var at = _data;
    for (final segment in _segments(path)) {
      at = switch (at) {
        final Map<Object?, Object?> map => map[segment],
        final List<Object?> list => switch (int.tryParse(segment)) {
          final index? when index >= 0 && index < list.length => list[index],
          _ => null,
        },
        _ => null,
      };
    }
    return at;
  }

  /// A prop's value: a binding `{"path": "/…"}` read from the data model,
  /// anything else as it is.
  Object? resolve(Object? prop) => switch (prop) {
    {'path': final String path} when prop.length == 1 => read(path),
    _ => prop,
  };

  /// [path]'s keys, unescaped (`~1` is `/`, `~0` is `~`); none for the root.
  static List<String> _segments(String path) => [
    for (final segment in path.split('/'))
      if (segment.isNotEmpty)
        segment.replaceAll('~1', '/').replaceAll('~0', '~'),
  ];

  /// [root] with [value] at [segments], making maps on the way.
  static Object? _write(Object? root, List<String> segments, Object? value) {
    if (segments.isEmpty) return value;
    final map = root is Map<Object?, Object?>
        ? Map<Object?, Object?>.of(root)
        : <Object?, Object?>{};
    final [key, ...rest] = segments;
    map[key] = _write(map[key], rest, value);
    return map;
  }
}
