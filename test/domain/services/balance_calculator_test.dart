import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/services/balance_calculator.dart';
import 'package:prioricash/domain/value_objects/money.dart';

/// SW-8 — BalanceCalculator.
///
/// The single most important rule in the whole project lives here:
/// available balance is NEVER clamped to zero. See SRS R5 and
/// AGENTS.md §1.2. A negative available balance is the exact signal this
/// app exists to surface.
///
/// Traces: R3 (no lower bound — overdue always included), R4 (overdue
/// funded before future by construction of the reservation set), R5 (never
/// clamp negative available).
void main() {
  DateTime d(int year, int month, int day) => DateTime(year, month, day);
  final horizonEnd = d(2026, 4, 14);

  const calculator = BalanceCalculator();

  ObligationInstance instance({
    String id = 'i-1',
    String obligationId = 'ob-1',
    required DateTime dueDate,
    int amountMinor = 100000,
    int fundedMinor = 0,
    bool isPaid = false,
  }) {
    return ObligationInstance(
      id: id,
      obligationId: obligationId,
      dueDate: dueDate,
      amount: Money.fromMinor(amountMinor),
      fundedAmount: Money.fromMinor(fundedMinor),
      isPaid: isPaid,
    );
  }

  group('reservedAmount', () {
    test(
      'sums the remaining shortfall of every instance within the horizon',
      () {
        final instances = [
          instance(id: 'i-1', dueDate: d(2026, 3, 20), amountMinor: 50000),
          instance(id: 'i-2', dueDate: d(2026, 4, 1), amountMinor: 75000),
        ];

        final reserved = calculator.reservedAmount(
          instances: instances,
          horizonEnd: horizonEnd,
        );

        expect(reserved, equals(Money.fromMinor(125000)));
      },
    );

    test('counts only the unfunded remainder, not the full amount', () {
      final instances = [
        instance(
          id: 'i-1',
          dueDate: d(2026, 3, 20),
          amountMinor: 100000,
          fundedMinor: 60000,
        ),
      ];

      final reserved = calculator.reservedAmount(
        instances: instances,
        horizonEnd: horizonEnd,
      );

      expect(reserved, equals(Money.fromMinor(40000)));
    });

    test('a fully-funded, unpaid instance with nothing actually spent yet '
        'reserves the full funded amount — SW-18', () {
      final instances = [
        instance(
          id: 'i-1',
          dueDate: d(2026, 3, 20),
          amountMinor: 100000,
          fundedMinor: 100000,
        ),
      ];

      final reserved = calculator.reservedAmount(
        instances: instances,
        horizonEnd: horizonEnd,
      );

      // No actualSpentByInstance entry — nothing recorded as spent, so
      // none of it is safe to release. This replaces the old rule that
      // dropped a fully-funded instance from reserved unconditionally.
      expect(reserved, equals(Money.fromMinor(100000)));
    });

    test('a fully-funded, unpaid instance reserves only what has not '
        'actually been spent yet — SW-18', () {
      final instances = [
        instance(
          id: 'i-1',
          dueDate: d(2026, 3, 20),
          amountMinor: 100000,
          fundedMinor: 100000,
        ),
      ];

      final reserved = calculator.reservedAmount(
        instances: instances,
        horizonEnd: horizonEnd,
        actualSpentByInstance: {'i-1': Money.fromMinor(40000)},
      );

      expect(reserved, equals(Money.fromMinor(60000)));
    });

    test(
      'a fully-funded, unpaid instance fully spent reserves nothing — SW-18',
      () {
        final instances = [
          instance(
            id: 'i-1',
            dueDate: d(2026, 3, 20),
            amountMinor: 100000,
            fundedMinor: 100000,
          ),
        ];

        final reserved = calculator.reservedAmount(
          instances: instances,
          horizonEnd: horizonEnd,
          actualSpentByInstance: {'i-1': Money.fromMinor(100000)},
        );

        expect(reserved, equals(Money.zero));
      },
    );

    test('spending recorded beyond the funded amount never reserves negative '
        '— SW-18', () {
      final instances = [
        instance(
          id: 'i-1',
          dueDate: d(2026, 3, 20),
          amountMinor: 100000,
          fundedMinor: 100000,
        ),
      ];

      final reserved = calculator.reservedAmount(
        instances: instances,
        horizonEnd: horizonEnd,
        actualSpentByInstance: {'i-1': Money.fromMinor(150000)},
      );

      expect(reserved, equals(Money.zero));
    });

    test('excludes an instance already marked paid', () {
      final instances = [
        instance(
          id: 'i-1',
          dueDate: d(2026, 3, 20),
          amountMinor: 100000,
          fundedMinor: 100000,
          isPaid: true,
        ),
      ];

      final reserved = calculator.reservedAmount(
        instances: instances,
        horizonEnd: horizonEnd,
      );

      expect(reserved, equals(Money.zero));
    });

    test('excludes an instance due after the horizon', () {
      final instances = [
        instance(id: 'i-1', dueDate: d(2026, 6, 1), amountMinor: 100000),
      ];

      final reserved = calculator.reservedAmount(
        instances: instances,
        horizonEnd: horizonEnd,
      );

      expect(reserved, equals(Money.zero));
    });

    test('an instance due exactly on the horizon end is included', () {
      final instances = [
        instance(id: 'i-1', dueDate: horizonEnd, amountMinor: 50000),
      ];

      final reserved = calculator.reservedAmount(
        instances: instances,
        horizonEnd: horizonEnd,
      );

      expect(reserved, equals(Money.fromMinor(50000)));
    });

    test('an empty instance list reserves nothing', () {
      final reserved = calculator.reservedAmount(
        instances: const [],
        horizonEnd: horizonEnd,
      );
      expect(reserved, equals(Money.zero));
    });

    test(
      'an overdue instance is still reserved — no lower date bound (R3)',
      () {
        final instances = [
          instance(id: 'i-overdue', dueDate: d(2026, 1, 1), amountMinor: 60000),
        ];

        final reserved = calculator.reservedAmount(
          instances: instances,
          horizonEnd: horizonEnd,
        );

        expect(reserved, equals(Money.fromMinor(60000)));
      },
    );

    test('mixes overdue and future instances in the same total', () {
      final instances = [
        instance(id: 'i-overdue', dueDate: d(2026, 1, 1), amountMinor: 60000),
        instance(id: 'i-future', dueDate: d(2026, 3, 25), amountMinor: 40000),
      ];

      final reserved = calculator.reservedAmount(
        instances: instances,
        horizonEnd: horizonEnd,
      );

      expect(reserved, equals(Money.fromMinor(100000)));
    });
  });

  group('availableBalance — R5', () {
    test('is total minus reserved when funds are sufficient', () {
      final available = calculator.availableBalance(
        total: Money.fromMinor(500000),
        reserved: Money.fromMinor(200000),
      );
      expect(available, equals(Money.fromMinor(300000)));
    });

    test('is exactly zero when reserved equals total', () {
      final available = calculator.availableBalance(
        total: Money.fromMinor(200000),
        reserved: Money.fromMinor(200000),
      );
      expect(available, equals(Money.zero));
      expect(available.isNegative, isFalse);
    });

    test(
      'is NEGATIVE when commitments exceed holdings — never clamped to zero',
      () {
        final available = calculator.availableBalance(
          total: Money.fromMinor(100000),
          reserved: Money.fromMinor(400000),
        );
        expect(available, equals(Money.fromMinor(-300000)));
        expect(available.isNegative, isTrue);
      },
    );

    test('a zero total with any reservation is negative, not zero', () {
      final available = calculator.availableBalance(
        total: Money.zero,
        reserved: Money.fromMinor(50000),
      );
      expect(available, equals(Money.fromMinor(-50000)));
    });

    test('zero total and zero reserved is exactly zero', () {
      final available = calculator.availableBalance(
        total: Money.zero,
        reserved: Money.zero,
      );
      expect(available, equals(Money.zero));
    });
  });

  group('end-to-end — the three balances together', () {
    test('reproduces the SRS worked example', () {
      final instances = [
        instance(id: 'i-wifi', dueDate: d(2026, 3, 20), amountMinor: 50000),
        instance(id: 'i-subs', dueDate: d(2026, 3, 25), amountMinor: 75000),
        instance(id: 'i-food', dueDate: d(2026, 4, 1), amountMinor: 200000),
      ];
      final total = Money.fromMinor(800000);

      final reserved = calculator.reservedAmount(
        instances: instances,
        horizonEnd: horizonEnd,
      );
      final available = calculator.availableBalance(
        total: total,
        reserved: reserved,
      );

      expect(reserved, equals(Money.fromMinor(325000)));
      expect(available, equals(Money.fromMinor(475000)));
    });

    test(
      'overdue accumulation drives available negative, matching acceptance criterion 3',
      () {
        final instances = [
          instance(id: 'i-o1', dueDate: d(2026, 1, 1), amountMinor: 200000),
          instance(id: 'i-o2', dueDate: d(2026, 2, 1), amountMinor: 200000),
          instance(id: 'i-o3', dueDate: d(2026, 2, 15), amountMinor: 200000),
        ];
        final total = Money.fromMinor(100000);

        final reserved = calculator.reservedAmount(
          instances: instances,
          horizonEnd: horizonEnd,
        );
        final available = calculator.availableBalance(
          total: total,
          reserved: reserved,
        );

        expect(reserved, equals(Money.fromMinor(600000)));
        expect(available, equals(Money.fromMinor(-500000)));
      },
    );
  });
}
