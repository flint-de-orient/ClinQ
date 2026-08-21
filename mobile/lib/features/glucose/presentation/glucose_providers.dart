import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/paged.dart';
import '../../../shared/providers/preferences_provider.dart';
import '../../../shared/services/notification_service.dart';
import '../data/glucose_repository.dart';
import '../domain/glucose_reading.dart';
import '../domain/glucose_trends.dart';

final FutureProvider<Paged<GlucoseReading>> glucoseReadingsProvider =
    FutureProvider<Paged<GlucoseReading>>(
      (ref) => ref.watch(glucoseRepositoryProvider).getReadings(limit: 30),
    );

/// The windows behind the 7D / 30D / 3M / 6M chips on the patient's home.
///
/// Days rather than calendar months on purpose: the endpoint takes a day
/// count, and "90 days" is what the clinic means by three months anyway —
/// nobody is comparing February to March.
enum GlucoseRange {
  d7(7, '7D'),
  d30(30, '30D'),
  m3(90, '3M'),
  m6(180, '6M');

  const GlucoseRange(this.days, this.label);

  final int days;
  final String label;
}

/// Trends over an arbitrary window.
///
/// `autoDispose` because a patient who glances at 6M once should not keep half
/// a year of readings resident for the rest of the session.
final glucoseTrendsRangeProvider = FutureProvider.autoDispose
    .family<GlucoseTrends, GlucoseRange>(
      (ref, range) =>
          ref.watch(glucoseRepositoryProvider).getTrends(days: range.days),
    );

/// The 30-day window, which is the default everywhere it is not chosen.
///
/// Kept as its own provider rather than an alias of the family: several
/// screens and the reminder scheduler read it without caring about ranges,
/// and it must not be disposed out from under them.
final FutureProvider<GlucoseTrends> glucoseTrendsProvider =
    FutureProvider<GlucoseTrends>(
      (ref) => ref.watch(glucoseRepositoryProvider).getTrends(days: 30),
    );

/// Drops every window at once. A new reading changes all of them, and a stale
/// 7D chart beside a fresh 30D one is the kind of contradiction a patient
/// notices and a clinician has to explain.
void invalidateGlucoseTrends(WidgetRef ref) {
  ref.invalidate(glucoseTrendsProvider);
  ref.invalidate(glucoseTrendsRangeProvider);
}

/// Re-arms the adaptive check-in reminder from the patient's most recent
/// reading. Honours the patient's toggle, so it is safe to call on app resume,
/// on login, and right after a reading is logged. [knownLast] skips the network
/// read when the caller already knows the latest reading time (e.g. it just
/// wrote one), which also avoids touching a provider from a widget being popped.
Future<void> syncCheckInReminder(WidgetRef ref, {DateTime? knownLast}) async {
  if (!ref.read(appPreferencesProvider).checkInReminders) {
    await NotificationService.instance.cancelCheckInReminder();
    return;
  }
  var last = knownLast;
  if (last == null) {
    try {
      final t = await ref.read(glucoseTrendsProvider.future);
      last = t.series.isNotEmpty ? t.series.last.at : null;
    } catch (_) {
      // No readings yet, or offline — fall through and arm a gentle first
      // nudge measured from now.
    }
  }
  await NotificationService.instance.scheduleCheckInReminder(
    lastReadingAt: last,
  );
}
