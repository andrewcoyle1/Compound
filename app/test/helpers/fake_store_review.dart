import 'package:compound/review/review_moment.dart';

/// The store's rating prompt, counting the times it was asked for.
class FakeStoreReview implements StoreReview {
  int requests = 0;

  @override
  Future<void> request() async => requests++;
}
