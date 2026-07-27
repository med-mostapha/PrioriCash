import 'package:meta/meta.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';
import 'package:prioricash/domain/value_objects/money.dart';

/// R13's three verdicts for a proposed purchase price.
enum PurchaseResult {
  /// Price does not exceed the available balance.
  safe,

  /// Price exceeds 70% of the available balance but not all of it — still
  /// affordable, but little room is left afterwards.
  tight,

  /// Price exceeds the available balance. Some currently-unfunded
  /// instances would be pushed out to make room — see [PurchaseVerdict.affectedInstances].
  breaksObligations,
}

/// The advisor's answer: a verdict plus, for
/// [PurchaseResult.breaksObligations], which specific commitments would go
/// underfunded — SRS R14.
@immutable
class PurchaseVerdict {
  const PurchaseVerdict({
    required this.result,
    required this.affectedInstances,
  });

  final PurchaseResult result;

  /// Empty unless [result] is [PurchaseResult.breaksObligations].
  final List<ObligationInstance> affectedInstances;
}

/// Evaluates a proposed purchase against the available balance — SRS R13
/// and R14.
///
/// Pure and read-only: never mutates anything, never touches storage. See
/// AGENTS.md §2.2.
@immutable
class PurchaseAdvisor {
  const PurchaseAdvisor();

  /// [available] is the balance already computed by BalanceCalculator —
  /// this advisor does not recompute it, keeping the two always in sync.
  /// [instances] and [obligationsById] are the same fundable set the
  /// allocation engine would use, so that "what would be sacrificed" is
  /// the exact mirror of "what gets funded first".
  PurchaseVerdict evaluate({
    required Money price,
    required Money available,
    required List<ObligationInstance> instances,
    required Map<String, Obligation> obligationsById,
    required DateTime today,
  }) {
    if (price.isZero || price.isNegative) {
      return const PurchaseVerdict(
        result: PurchaseResult.safe,
        affectedInstances: [],
      );
    }

    if (available.isNegative || price.compareTo(available) > 0) {
      return PurchaseVerdict(
        result: PurchaseResult.breaksObligations,
        affectedInstances: _findAffected(
          shortfall: price.subtract(available),
          instances: instances,
          obligationsById: obligationsById,
        ),
      );
    }

    final threshold = _scaledThreshold(available);
    if (price.compareTo(threshold) > 0) {
      return const PurchaseVerdict(
        result: PurchaseResult.tight,
        affectedInstances: [],
      );
    }

    return const PurchaseVerdict(
      result: PurchaseResult.safe,
      affectedInstances: [],
    );
  }

  /// 70% of [available], computed in integer minor units. Avoids floating
  /// point entirely, per R11 — multiply first, then divide.
  Money _scaledThreshold(Money available) {
    final scaledMinor = (available.minorUnits * 7) ~/ 10;
    return Money.fromMinor(scaledMinor, currency: available.currency);
  }

  /// Walks the candidate instances from the furthest-out due date backward
  /// — the reverse of allocation order — removing enough of them to absorb
  /// [shortfall]. These are the commitments that would end up unfunded if
  /// the purchase went through, because the money that would have covered
  /// them is spent instead.
  ///
  /// Only unfunded instances are candidates: one already fully funded has
  /// nothing left to lose.
  List<ObligationInstance> _findAffected({
    required Money shortfall,
    required List<ObligationInstance> instances,
    required Map<String, Obligation> obligationsById,
  }) {
    final unfunded = instances.where((i) => !i.isFullyFunded).toList()
      ..sort((a, b) {
        final byDate = b.dueDate.compareTo(a.dueDate);
        if (byDate != 0) return byDate;
        final priorityA = obligationsById[a.obligationId]?.priority.index ?? 0;
        final priorityB = obligationsById[b.obligationId]?.priority.index ?? 0;
        return priorityB.compareTo(priorityA);
      });

    final affected = <ObligationInstance>[];
    var remaining = shortfall;
    for (final instance in unfunded) {
      if (remaining.isZero || remaining.isNegative) break;
      affected.add(instance);
      remaining = remaining.subtract(instance.remaining());
    }
    return affected;
  }
}
