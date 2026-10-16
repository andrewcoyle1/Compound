import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_repository/purchases_repository.dart';

void main() {
  group(FakePurchasesRepository, () {
    const yearly = FakePurchasesRepository.sampleProducts;

    test("sells the Swift app's development products", () async {
      final repository = FakePurchasesRepository();
      expect(
        await repository.getProducts(
          SubscriptionPlan.productIds(development: true),
        ),
        FakePurchasesRepository.sampleProducts,
      );
      expect(
        await repository.getProducts(
          SubscriptionPlan.productIds(development: false),
        ),
        isEmpty,
      );
      expect(yearly.map((p) => p.priceString), ['£29.99', '£4.99']);
    });

    test('is premium once logged in by default', () async {
      final repository = FakePurchasesRepository();
      expect(repository.state.isResolved, isFalse);
      final entitlements = await repository.logIn('uid');
      expect(entitlements.single.productId, yearly.first.id);
      expect(repository.state.isResolved, isTrue);
      expect(repository.state.isPremiumWith(), isTrue);
    });

    test('a non-premium user is sent to the paywall once logged in', () async {
      final repository = FakePurchasesRepository(premium: false);
      expect(repository.state.isPremiumWith(), isTrue);
      await repository.logIn('uid');
      expect(repository.state.isPremiumWith(), isFalse);
    });

    test('buying makes the user premium and emits the change', () async {
      final repository = FakePurchasesRepository(premium: false);
      await repository.logIn('uid');
      final states = <PurchasesState>[];
      final subscription = repository.states.listen(states.add);
      final entitlements = await repository.purchase(yearly.last);
      await Future<void>.delayed(Duration.zero);
      expect(entitlements.single.productId, yearly.last.id);
      expect(entitlements.single.isActive, isTrue);
      expect(states.map((s) => s.isPremiumWith()), [false, true]);
      await subscription.cancel();
    });

    test('buying the same plan again keeps one entitlement for it', () async {
      final repository = FakePurchasesRepository();
      expect(await repository.purchase(yearly.first), hasLength(1));
    });

    test('an unknown product is not found', () async {
      final repository = FakePurchasesRepository(products: const []);
      await expectLater(
        repository.purchase(yearly.first),
        throwsA(isA<ProductNotFound>()),
      );
    });

    test('queued failures are thrown in turn by purchase or restore', () async {
      final repository = FakePurchasesRepository(
        premium: false,
        failures: const [PurchaseCancelled(), PurchasePending()],
      );
      await expectLater(
        repository.purchase(yearly.first),
        throwsA(isA<PurchaseCancelled>()),
      );
      await expectLater(repository.restore(), throwsA(isA<PurchasePending>()));
      expect(repository.failures, isEmpty);
      expect(await repository.restore(), isEmpty);
    });

    test('a plan already owned is found by the restore after it', () async {
      final repository = FakePurchasesRepository(
        premium: false,
        failures: const [ProductAlreadyOwned()],
      );
      await repository.logIn('uid');
      await expectLater(
        repository.purchase(yearly.last),
        throwsA(isA<ProductAlreadyOwned>()),
      );
      expect((await repository.restore()).single.productId, yearly.last.id);
    });

    test('failed loads throw, then the products load', () async {
      final repository = FakePurchasesRepository(failedLoads: 1);
      final ids = SubscriptionPlan.productIds(development: true);
      await expectLater(
        repository.getProducts(ids),
        throwsA(isA<PurchasesFailure>()),
      );
      expect(repository.failedLoads, 0);
      expect(await repository.getProducts(ids), hasLength(2));
    });

    test('restore and refresh return what the account owns', () async {
      final repository = FakePurchasesRepository();
      expect(await repository.restore(), hasLength(1));
      expect(await repository.refresh(), hasLength(1));
    });

    test('logging out returns to unresolved', () async {
      final repository = FakePurchasesRepository();
      await repository.logIn('uid');
      await repository.logOut();
      expect(repository.state.isResolved, isFalse);
      await repository.close();
    });
  });
}
