import 'dart:async';
import 'dart:developer' as developer;

/// Called with a document's path (or a batch's collection path) when the
/// server refuses a write that Firestore had already applied locally: for
/// example `permission-denied`, or `not-found` for an `update()` of a
/// document that does not exist.
typedef WriteErrorReporter = void Function(
  String path,
  Object error,
  StackTrace stackTrace,
);

/// The default [WriteErrorReporter]: `dart:developer`'s log at the severe
/// level. The app passes one that also records a severe analytics event.
void logWriteError(String path, Object error, StackTrace stackTrace) =>
    developer.log(
      'The server refused the write to $path',
      name: 'firestore_writes',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );

/// Starts [write] and completes once Firestore has it, without waiting for
/// the server (`docs/specs/flutter/firestore-contract.md`, Policy).
///
/// cloud_firestore's `set`, `update` and `commit` complete only when the
/// server acknowledges, so offline they never would. Firestore applies a
/// write to its local cache, and queues it durably, as soon as it is
/// started, as the Swift sync engines do with their pending writes.
///
/// - An error raised while starting the write, before the event loop moves
///   on (the encoder rejecting a value, say), fails the returned future:
///   the write never happened, and the caller can say so.
/// - Anything later, which can only come from the platform side (the
///   server refusing it), goes to [onError] instead.
///
/// So this completes when the write succeeds or after one turn of the event
/// loop, whichever is first. Fakes that resolve in microtasks therefore
/// behave as if they were online.
Future<void> writeLocally(
  String path,
  Future<void> Function() write,
  WriteErrorReporter onError,
) async {
  var starting = true;
  final written = write().then<void>(
    (_) {},
    onError: (Object error, StackTrace stackTrace) {
      if (starting) Error.throwWithStackTrace(error, stackTrace);
      onError(path, error, stackTrace);
    },
  );
  await Future.any([
    written,
    Future<void>.delayed(Duration.zero, () => starting = false),
  ]);
}
