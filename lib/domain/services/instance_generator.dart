import 'package:meta/meta.dart';
import 'package:prioricash/domain/entities/obligation.dart';
import 'package:prioricash/domain/entities/obligation_instance.dart';

/// Turns [Obligation] templates into dated [ObligationInstance] occurrences.
///
/// Pure domain service: it never queries storage. The caller (the data
/// layer) fetches what already exists and passes it in as [existing]. This
/// keeps generation testable with `dart test` alone — see AGENTS.md §2.2.
///
/// The one property that matters: running generation twice over the same
/// obligation and horizon must never create a duplicate. See SRS R15.
@immutable
class InstanceGenerator {
  const InstanceGenerator();

  /// Generates the occurrences of [obligation] due on or before
  /// [horizonEnd] that are not already present in [existing].
  ///
  /// Only [existing] instances belonging to this same obligation are
  /// considered — instances from other obligations are ignored even if a
  /// due date coincides.
  List<ObligationInstance> generate({
    required Obligation obligation,
    required DateTime horizonEnd,
    required List<ObligationInstance> existing,
  }) {
    if (obligation.startDate.isAfter(horizonEnd)) {
      return const [];
    }

    final dueDates = obligation.dueDatesBetween(
      from: obligation.startDate,
      to: horizonEnd,
    );
    final alreadyPresent = existing
        .where((instance) => instance.obligationId == obligation.id)
        .map((instance) => instance.id)
        .toSet();

    return dueDates
        .map((dueDate) => _buildInstance(obligation, dueDate))
        .where((instance) => !alreadyPresent.contains(instance.id))
        .toList(growable: false);
  }

  /// Convenience for generating across every active obligation at once,
  /// e.g. on app launch or date change (UC-12).
  List<ObligationInstance> generateAll({
    required List<Obligation> obligations,
    required DateTime horizonEnd,
    required List<ObligationInstance> existing,
  }) {
    return obligations
        .expand(
          (obligation) => generate(
            obligation: obligation,
            horizonEnd: horizonEnd,
            existing: existing,
          ),
        )
        .toList(growable: false);
  }

  /// The id is deterministic — obligationId + due date — rather than
  /// randomly generated. That is what makes idempotency checkable by id
  /// alone, with no separate index or database round trip required.
  ObligationInstance _buildInstance(Obligation obligation, DateTime dueDate) {
    return ObligationInstance(
      id: _instanceId(obligation.id, dueDate),
      obligationId: obligation.id,
      dueDate: dueDate,
      amount: obligation.amount,
    );
  }

  static String _instanceId(String obligationId, DateTime dueDate) {
    final y = dueDate.year.toString().padLeft(4, '0');
    final m = dueDate.month.toString().padLeft(2, '0');
    final day = dueDate.day.toString().padLeft(2, '0');
    return '$obligationId#$y-$m-$day';
  }
}
