import 'dart:math';

import 'package:compound/app/document_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('newDocumentId', () {
    final uuid = RegExp(
      r'^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$',
    );

    test("is an upper-case version 4 UUID, as Swift's uuidString", () {
      for (var i = 0; i < 100; i++) {
        expect(newDocumentId(), matches(uuid));
      }
    });

    test('differs every call', () {
      expect({for (var i = 0; i < 100; i++) newDocumentId()}, hasLength(100));
    });

    test('is fixed by the random source', () {
      expect(newDocumentId(Random(1)), newDocumentId(Random(1)));
    });
  });
}
