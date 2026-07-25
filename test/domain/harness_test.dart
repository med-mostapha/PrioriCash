import 'package:flutter_test/flutter_test.dart';

/// Proves the test harness runs before any domain code exists.
/// Delete this once Money has its own test file (SW-2).
void main() {
  test('test harness is wired up', () {
    expect(1 + 1, equals(2));
  });
}
