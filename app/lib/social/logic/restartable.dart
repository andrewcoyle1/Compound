import 'dart:async';

import 'package:bloc/bloc.dart';

/// An event transformer that cancels the handler still running for an
/// earlier event when a new one arrives, as `bloc_concurrency`'s
/// `restartable` does. Used for listeners that must restart when what they
/// listen to changes, and for debounced searches.
// ponytail: a dozen lines instead of the bloc_concurrency package; switch to
// it if a second transformer is needed.
EventTransformer<E> restartable<E>() =>
    (events, mapper) => Stream.multi((controller) {
      StreamSubscription<E>? inner;
      final outer = events.listen(
        (event) {
          unawaited(inner?.cancel());
          inner = mapper(event)
              .listen(controller.add, onError: controller.addError);
        },
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () async {
        await inner?.cancel();
        await outer.cancel();
      };
    });
