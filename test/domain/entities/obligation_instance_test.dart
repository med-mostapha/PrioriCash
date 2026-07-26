import 'package:flutter_test/flutter_test.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/value_objects/money.dart';

/// SW-4 — ObligationInstance and computeStatus().
///
/// The five states here are the state machine from SRS §6.2. Getting the
/// precedence wrong silently removes commitments from the reservation set.
void main() {
  DateTime d(int year, int month, int day) => DateTime(year, month, day);

  final today = d(2026, 3, 15);

  ObligationInstance build({
    String id = 'inst-1',
    String obligationId = 'ob-1',
    DateTime? dueDate,
    int amountMinor = 50000,
    int fundedMinor = 0,
    bool isPaid = false,
  }) {
    return ObligationInstance(
      id: id,
      obligationId: obligationId,
      dueDate: dueDate ?? d(2026, 3, 20),
      amount: Money.fromMinor(amountMinor),
      fundedAmount: Money.fromMinor(fundedMinor),
      isPaid: isPaid,
    );
  }

  group('construction', () {
    test('keeps the values given', () {
      final i = build(fundedMinor: 20000);
      expect(i.id, equals('inst-1'));
      expect(i.obligationId, equals('ob-1'));
      expect(i.amount, equals(Money.fromMinor(50000)));
      expect(i.fundedAmount, equals(Money.fromMinor(20000)));
      expect(i.isPaid, isFalse);
    });

    test('funded defaults to zero', () {
      final i = ObligationInstance(
        id: 'inst-2',
        obligationId: 'ob-1',
        dueDate: d(2026, 4, 1),
        amount: Money.fromMinor(1000),
      );
      expect(i.fundedAmount, equals(Money.zero));
    });

    test('rejects empty identifiers', () {
      expect(() => build(id: ''), throwsArgumentError);
      expect(() => build(obligationId: ''), throwsArgumentError);
    });

    test('rejects a non-positive amount', () {
      expect(() => build(amountMinor: 0), throwsArgumentError);
      expect(() => build(amountMinor: -1), throwsArgumentError);
    });

    test('rejects negative funding', () {
      expect(() => build(fundedMinor: -1), throwsArgumentError);
    });
  });

  group('remaining and isFullyFunded', () {
    test('remaining is amount minus funded', () {
      expect(
        build(amountMinor: 50000, fundedMinor: 20000).remaining(),
        equals(Money.fromMinor(30000)),
      );
    });

    test('remaining is zero once fully funded', () {
      expect(
        build(amountMinor: 50000, fundedMinor: 50000).remaining(),
        equals(Money.zero),
      );
    });

    test('isFullyFunded is false while short', () {
      expect(build(fundedMinor: 49999).isFullyFunded, isFalse);
    });

    test('isFullyFunded is true at exactly the amount', () {
      expect(build(fundedMinor: 50000).isFullyFunded, isTrue);
    });
  });

  group('daysUntilDue', () {
    test('is positive before the due date', () {
      expect(build(dueDate: d(2026, 3, 20)).daysUntilDue(today), equals(5));
    });

    test('is zero on the due date', () {
      expect(build(dueDate: d(2026, 3, 15)).daysUntilDue(today), equals(0));
    });

    test('is negative once overdue', () {
      expect(build(dueDate: d(2026, 3, 10)).daysUntilDue(today), equals(-5));
    });

    test('counts across a month boundary', () {
      expect(build(dueDate: d(2026, 4, 15)).daysUntilDue(today), equals(31));
    });

    test('ignores the time of day', () {
      final i = build(dueDate: DateTime(2026, 3, 20, 23, 59));
      expect(i.daysUntilDue(DateTime(2026, 3, 15, 0, 1)), equals(5));
    });
  });

  // -----------------------------------------------------------------------
  // computeStatus — the whole state machine. Precedence is the point.
  // -----------------------------------------------------------------------
  group('computeStatus', () {
    test('pending: nothing funded, still in the future', () {
      expect(
        build(dueDate: d(2026, 3, 20)).computeStatus(today),
        equals(InstanceStatus.pending),
      );
    });

    test('partial: partly funded, still in the future', () {
      expect(
        build(dueDate: d(2026, 3, 20), fundedMinor: 20000).computeStatus(today),
        equals(InstanceStatus.partial),
      );
    });

    test('funded: fully covered before the due date', () {
      expect(
        build(dueDate: d(2026, 3, 20), fundedMinor: 50000).computeStatus(today),
        equals(InstanceStatus.funded),
      );
    });

    test('overdue: nothing funded, due date passed', () {
      expect(
        build(dueDate: d(2026, 3, 10)).computeStatus(today),
        equals(InstanceStatus.overdue),
      );
    });

    test('overdue beats partial: partly funded and late reads as overdue', () {
      expect(
        build(dueDate: d(2026, 3, 10), fundedMinor: 20000).computeStatus(today),
        equals(InstanceStatus.overdue),
      );
    });

    test('funded beats overdue: money is already set aside', () {
      expect(
        build(dueDate: d(2026, 3, 10), fundedMinor: 50000).computeStatus(today),
        equals(InstanceStatus.funded),
      );
    });

    test('paid beats everything', () {
      expect(
        build(
          dueDate: d(2026, 3, 10),
          fundedMinor: 50000,
          isPaid: true,
        ).computeStatus(today),
        equals(InstanceStatus.paid),
      );
    });

    test('due today is not yet overdue', () {
      expect(
        build(dueDate: d(2026, 3, 15)).computeStatus(today),
        equals(InstanceStatus.pending),
      );
    });

    test('status follows the clock, not stored state', () {
      final i = build(dueDate: d(2026, 3, 20));
      expect(i.computeStatus(d(2026, 3, 15)), equals(InstanceStatus.pending));
      expect(i.computeStatus(d(2026, 3, 25)), equals(InstanceStatus.overdue));
    });
  });

  group('isOverdue', () {
    test('true when late and unfunded', () {
      expect(build(dueDate: d(2026, 3, 10)).isOverdue(today), isTrue);
    });

    test('false when late but fully funded', () {
      expect(
        build(dueDate: d(2026, 3, 10), fundedMinor: 50000).isOverdue(today),
        isFalse,
      );
    });

    test('false when late but already paid', () {
      expect(
        build(
          dueDate: d(2026, 3, 10),
          fundedMinor: 50000,
          isPaid: true,
        ).isOverdue(today),
        isFalse,
      );
    });

    test('false before the due date', () {
      expect(build(dueDate: d(2026, 3, 20)).isOverdue(today), isFalse);
    });
  });

  group('applyFunding', () {
    test('adds to the funded amount', () {
      final i = build().applyFunding(Money.fromMinor(20000));
      expect(i.fundedAmount, equals(Money.fromMinor(20000)));
    });

    test('accumulates across calls', () {
      final i = build()
          .applyFunding(Money.fromMinor(20000))
          .applyFunding(Money.fromMinor(10000));
      expect(i.fundedAmount, equals(Money.fromMinor(30000)));
    });

    test('does not mutate the original', () {
      final original = build();
      original.applyFunding(Money.fromMinor(20000));
      expect(original.fundedAmount, equals(Money.zero));
    });

    test('exactly covering the remainder is allowed', () {
      final i = build(fundedMinor: 30000).applyFunding(Money.fromMinor(20000));
      expect(i.isFullyFunded, isTrue);
    });

    test('overfunding throws rather than capping', () {
      expect(
        () => build(fundedMinor: 30000).applyFunding(Money.fromMinor(20001)),
        throwsArgumentError,
      );
    });

    test('rejects zero or negative payments', () {
      expect(() => build().applyFunding(Money.zero), throwsArgumentError);
      expect(
        () => build().applyFunding(Money.fromMinor(-1)),
        throwsArgumentError,
      );
    });

    test('cannot fund an occurrence already paid', () {
      expect(
        () => build(
          fundedMinor: 50000,
          isPaid: true,
        ).applyFunding(Money.fromMinor(1)),
        throwsStateError,
      );
    });
  });

  // -----------------------------------------------------------------------
  // Undo depends on this being exact — SRS R10 and acceptance criterion 4.
  // -----------------------------------------------------------------------
  group('reverseFunding', () {
    test('subtracts from the funded amount', () {
      final i = build(
        fundedMinor: 30000,
      ).reverseFunding(Money.fromMinor(10000));
      expect(i.fundedAmount, equals(Money.fromMinor(20000)));
    });

    test('restores the exact prior state', () {
      final before = build(fundedMinor: 20000);
      final after = before
          .applyFunding(Money.fromMinor(15000))
          .reverseFunding(Money.fromMinor(15000));
      expect(after.fundedAmount, equals(before.fundedAmount));
      expect(after.computeStatus(today), equals(before.computeStatus(today)));
    });

    test('reversing everything returns to zero', () {
      final i = build(
        fundedMinor: 50000,
      ).reverseFunding(Money.fromMinor(50000));
      expect(i.fundedAmount, equals(Money.zero));
      expect(i.computeStatus(today), equals(InstanceStatus.pending));
    });

    test('cannot reverse more than was funded', () {
      expect(
        () => build(fundedMinor: 20000).reverseFunding(Money.fromMinor(20001)),
        throwsArgumentError,
      );
    });

    test('rejects zero or negative amounts', () {
      expect(() => build().reverseFunding(Money.zero), throwsArgumentError);
    });
  });

  group('markPaid', () {
    test('sets isPaid on a fully funded occurrence', () {
      final i = build(fundedMinor: 50000).markPaid();
      expect(i.isPaid, isTrue);
      expect(i.computeStatus(today), equals(InstanceStatus.paid));
    });

    test('refuses while underfunded', () {
      expect(() => build(fundedMinor: 49999).markPaid(), throwsStateError);
    });

    test('refuses twice', () {
      expect(
        () => build(fundedMinor: 50000, isPaid: true).markPaid(),
        throwsStateError,
      );
    });

    test('does not mutate the original', () {
      final original = build(fundedMinor: 50000);
      original.markPaid();
      expect(original.isPaid, isFalse);
    });
  });

  group('entity equality', () {
    test('same id means equal regardless of funding', () {
      expect(build(fundedMinor: 0), equals(build(fundedMinor: 50000)));
    });

    test('different ids are not equal', () {
      expect(build(id: 'a'), isNot(equals(build(id: 'b'))));
    });

    test('a mutation returns an object equal to its source', () {
      final original = build();
      expect(original.applyFunding(Money.fromMinor(100)), equals(original));
    });
  });
}
