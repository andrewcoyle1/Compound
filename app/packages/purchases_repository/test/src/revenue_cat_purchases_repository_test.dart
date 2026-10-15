import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_repository/purchases_repository.dart';

const _channel = MethodChannel('purchases_flutter');

Map<String, Object?> _entitlementJson({
  required String productId,
  required bool isActive,
  String? expirationDate,
}) => {
  'identifier': 'pro',
  'isActive': isActive,
  'willRenew': isActive,
  'latestPurchaseDate': '2026-10-01T09:00:00Z',
  'originalPurchaseDate': '2026-01-01T09:00:00Z',
  'productIdentifier': productId,
  'isSandbox': true,
  'expirationDate': expirationDate,
};

/// RevenueCat's CustomerInfo JSON, as the native SDKs send it.
Map<String, Object?> _customerInfo([
  Map<String, Map<String, Object?>> entitlements = const {},
]) => {
  'entitlements': {
    'all': entitlements,
    'active': {
      for (final entry in entitlements.entries)
        if (entry.value['isActive'] == true) entry.key: entry.value,
    },
    'verification': 'NOT_REQUESTED',
  },
  'allPurchaseDates': <String, Object?>{},
  'activeSubscriptions': <Object?>[],
  'allPurchasedProductIdentifiers': <Object?>[],
  'nonSubscriptionTransactions': <Object?>[],
  'firstSeen': '2026-01-01T09:00:00Z',
  'originalAppUserId': 'uid',
  'allExpirationDates': <String, Object?>{},
  'requestDate': '2026-10-15T09:00:00Z',
};

final Map<String, Object?> _active = _customerInfo({
  'pro': _entitlementJson(
    productId: 'com.andrewcoyle.compound.monthly',
    isActive: true,
    expirationDate: '2026-11-01T09:00:00Z',
  ),
});

Map<String, Object?> _storeProduct(String id, {String? period = 'P1Y'}) => {
  'identifier': id,
  'description': 'Unlock workout, AI nutrition, and weight tracking.',
  'title': 'Pro Annual',
  'price': 29.99,
  'priceString': '£29.99',
  'currencyCode': 'GBP',
  'productCategory': 'SUBSCRIPTION',
  'subscriptionPeriod': period,
};

const _yearlyId = 'com.andrewcoyle.compound.yearly';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group(RevenueCatPurchasesRepository, () {
    late List<MethodCall> calls;
    late Map<String, Object? Function(MethodCall)> answers;

    setUp(() {
      calls = [];
      answers = {
        'logIn': (_) => {'customerInfo': _active, 'created': false},
        'logOut': (_) => _customerInfo(),
        'getCustomerInfo': (_) => _active,
        'restorePurchases': (_) => _customerInfo(),
        'getProductInfo': (_) => [_storeProduct(_yearlyId)],
        'purchaseProduct': (_) => {
          'customerInfo': _active,
          'transaction': {
            'transactionIdentifier': 't',
            'productIdentifier': _yearlyId,
            'purchaseDate': '2026-10-15T09:00:00Z',
          },
        },
      };
      messenger.setMockMethodCallHandler(_channel, (call) async {
        calls.add(call);
        return answers[call.method]?.call(call);
      });
    });

    tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

    PlatformException storeError(PurchasesErrorCode code) =>
        PlatformException(code: '${code.index}', message: code.name);

    void fail(String method, PlatformException error) =>
        answers[method] = (_) => throw error;

    /// RevenueCat telling the app about new customer info.
    Future<void> pushCustomerInfo(Map<String, Object?> info) =>
        messenger.handlePlatformMessage(
          _channel.name,
          _channel.codec.encodeMethodCall(
            MethodCall('Purchases-CustomerInfoUpdated', info),
          ),
          (_) {},
        );

    group('without an API key', () {
      late RevenueCatPurchasesRepository repository;

      setUp(() async {
        repository = await RevenueCatPurchasesRepository.init(apiKey: '');
      });

      test('configures nothing and is not premium', () async {
        expect(calls, isEmpty);
        expect(repository.state.isResolved, isTrue);
        expect(repository.state.isPremiumWith(), isFalse);
        expect(await repository.logIn('uid'), isEmpty);
        expect(await repository.refresh(), isEmpty);
        await repository.logOut();
        await repository.close();
        expect(calls, isEmpty);
      });

      test('refuses to load, buy or restore', () async {
        final failure = throwsA(isA<PurchasesNotConfigured>());
        await expectLater(repository.getProducts([_yearlyId]), failure);
        await expectLater(
          repository.purchase(
            const SubscriptionProduct(
              id: _yearlyId,
              title: 'Pro Annual',
              subtitle: '',
              priceString: '£29.99',
            ),
          ),
          failure,
        );
        await expectLater(repository.restore(), failure);
      });
    });

    group('with an API key', () {
      late RevenueCatPurchasesRepository repository;

      setUp(() async {
        repository = await RevenueCatPurchasesRepository.init(
          apiKey: 'goog_test',
        );
      });

      tearDown(() => repository.close());

      test('configures RevenueCat anonymously and starts unresolved', () {
        final setup = calls.single;
        expect(setup.method, 'setupPurchases');
        final arguments = setup.arguments as Map<Object?, Object?>;
        expect(arguments['apiKey'], 'goog_test');
        expect(arguments['appUserId'], isNull);
        expect(repository.state.isResolved, isFalse);
      });

      test('configures as the signed-in user when there is one', () async {
        calls.clear();
        final signedIn = await RevenueCatPurchasesRepository.init(
          apiKey: 'appl_test',
          appUserId: 'uid',
        );
        final arguments = calls.single.arguments as Map<Object?, Object?>;
        expect(arguments['appUserId'], 'uid');
        await pushCustomerInfo(_active);
        expect(signedIn.state.isResolved, isTrue);
        expect(signedIn.state.isPremiumWith(), isTrue);
        await signedIn.close();
      });

      test('an anonymous update does not resolve the state', () async {
        await pushCustomerInfo(_customerInfo());
        expect(repository.state.isResolved, isFalse);
        expect(repository.state.isPremiumWith(), isTrue);
      });

      test('logs in with the uid, resolves and sends attributes', () async {
        final states = <PurchasesState>[];
        final subscription = repository.states.listen(states.add);
        final entitlements = await repository.logIn(
          'uid',
          email: 'a@b.c',
          mixpanelDistinctId: 'mp',
          firebaseAppInstanceId: 'fb',
        );
        expect(
          entitlements.single.productId,
          'com.andrewcoyle.compound.monthly',
        );
        expect(entitlements.single.isActive, isTrue);
        expect(entitlements.single.isSandbox, isTrue);
        expect(
          entitlements.single.expirationDate,
          DateTime.utc(2026, 11, 1, 9),
        );
        expect(calls.skip(1).map((c) => c.method), [
          'logIn',
          'setEmail',
          'setMixpanelDistinctID',
          'setFirebaseAppInstanceID',
        ]);
        expect(calls.skip(1).map((c) => c.arguments), [
          {'appUserID': 'uid'},
          {'email': 'a@b.c'},
          {'mixpanelDistinctID': 'mp'},
          {'firebaseAppInstanceID': 'fb'},
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(states.last.isResolved, isTrue);
        expect(states.last.isPremiumWith(), isTrue);
        await subscription.cancel();
      });

      test('a lapsed subscriber is not premium once logged in', () async {
        answers['logIn'] = (_) => {
          'customerInfo': _customerInfo({
            'pro': _entitlementJson(
              productId: _yearlyId,
              isActive: false,
              expirationDate: '2025-01-01T00:00:00Z',
            ),
          }),
          'created': false,
        };
        await repository.logIn('uid');
        expect(calls.last.method, 'logIn');
        expect(repository.state.isResolved, isTrue);
        expect(repository.state.isPremiumWith(), isFalse);
      });

      test('lists entitlements latest expiry first', () async {
        answers['getCustomerInfo'] = (_) => _customerInfo({
          'old': _entitlementJson(
            productId: 'old',
            isActive: false,
            expirationDate: '2025-01-01T00:00:00Z',
          ),
          'lifetime': _entitlementJson(productId: 'lifetime', isActive: true),
          'pro': _entitlementJson(
            productId: 'pro',
            isActive: true,
            expirationDate: '2026-12-01T00:00:00Z',
          ),
        });
        expect((await repository.refresh()).map((e) => e.productId), [
          'pro',
          'old',
          'lifetime',
        ]);
        // Not logged in, so still not a resolved answer.
        expect(repository.state.isResolved, isFalse);
      });

      test('logging out forgets the user before asking RevenueCat', () async {
        await repository.logIn('uid');
        fail('logOut', storeError(PurchasesErrorCode.networkError));
        await expectLater(
          repository.logOut(),
          throwsA(isA<PurchasesFailure>()),
        );
        expect(repository.state, const PurchasesState());
        await pushCustomerInfo(_active);
        expect(repository.state.isResolved, isFalse);
      });

      test('logging out an anonymous user is not an error', () async {
        fail(
          'logOut',
          storeError(PurchasesErrorCode.logOutWithAnonymousUserError),
        );
        await repository.logOut();
        answers['logOut'] = (_) => _customerInfo();
        await repository.logOut();
        expect(calls.where((c) => c.method == 'logOut'), hasLength(2));
      });

      test('loads products by id', () async {
        answers['getProductInfo'] = (_) => [
          _storeProduct(_yearlyId),
          _storeProduct('one-off', period: null),
        ];
        final products = await repository.getProducts([_yearlyId, 'one-off']);
        expect(calls.last.arguments, {
          'productIdentifiers': [_yearlyId, 'one-off'],
          'type': 'subscription',
        });
        expect(
          products.first,
          const SubscriptionProduct(
            id: _yearlyId,
            title: 'Pro Annual',
            subtitle: 'Unlock workout, AI nutrition, and weight tracking.',
            priceString: '£29.99',
            duration: ProductDuration.year,
          ),
        );
        expect(products.last.duration, isNull);
      });

      test('buys a loaded product without fetching it again', () async {
        final product = (await repository.getProducts([_yearlyId])).single;
        await repository.logIn('uid');
        calls.clear();
        final entitlements = await repository.purchase(product);
        expect(calls.single.method, 'purchaseProduct');
        expect(
          (calls.single.arguments
              as Map<Object?, Object?>)['productIdentifier'],
          _yearlyId,
        );
        expect(entitlements.single.isActive, isTrue);
        expect(repository.state.isPremiumWith(), isTrue);
      });

      test('fetches a product it has not loaded before buying it', () async {
        const product = SubscriptionProduct(
          id: _yearlyId,
          title: 'Pro Annual',
          subtitle: '',
          priceString: '£29.99',
        );
        await repository.purchase(product);
        expect(calls.skip(1).map((c) => c.method), [
          'getProductInfo',
          'purchaseProduct',
        ]);
      });

      test('a product the store does not sell is not found', () async {
        answers['getProductInfo'] = (_) => <Object?>[];
        await expectLater(
          repository.purchase(
            const SubscriptionProduct(
              id: 'nope',
              title: '',
              subtitle: '',
              priceString: '',
            ),
          ),
          throwsA(isA<ProductNotFound>()),
        );
      });

      test(
        'sorts purchase errors into cancel, pending, owned and failure',
        () async {
          final product = (await repository.getProducts([_yearlyId])).single;
          final cases = {
            PurchasesErrorCode.purchaseCancelledError: isA<PurchaseCancelled>(),
            PurchasesErrorCode.paymentPendingError: isA<PurchasePending>(),
            PurchasesErrorCode.productAlreadyPurchasedError:
                isA<ProductAlreadyOwned>(),
            PurchasesErrorCode.storeProblemError: isA<PurchasesFailure>()
                .having((f) => f.error, 'error', isA<PlatformException>()),
          };
          for (final MapEntry(key: code, value: matcher) in cases.entries) {
            fail('purchaseProduct', storeError(code));
            await expectLater(repository.purchase(product), throwsA(matcher));
          }
        },
      );

      test('an unrecognised error code is a plain failure', () async {
        for (final code in ['x', '-1', '9999']) {
          fail('restorePurchases', PlatformException(code: code));
          await expectLater(
            repository.restore(),
            throwsA(
              isA<PurchasesFailure>().having(
                (f) => f.runtimeType,
                'type',
                PurchasesFailure,
              ),
            ),
          );
        }
      });

      test('restores and refreshes', () async {
        await repository.logIn('uid');
        expect(await repository.restore(), isEmpty);
        expect(repository.state.isPremiumWith(), isFalse);
        expect(await repository.refresh(), hasLength(1));
        expect(repository.state.isPremiumWith(), isTrue);
      });

      test('an unchanged answer emits nothing new', () async {
        await repository.logIn('uid');
        final states = <PurchasesState>[];
        final subscription = repository.states.listen(states.add);
        await repository.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(states, hasLength(1));
        await subscription.cancel();
      });

      test('stops listening once closed', () async {
        final before = repository.state;
        await repository.close();
        await pushCustomerInfo(
          _customerInfo({
            'other': _entitlementJson(productId: 'other', isActive: false),
          }),
        );
        expect(repository.state, before);
      });
    });
  });
}
