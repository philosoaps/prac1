import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/calendar/v3.dart' as goog_cal;

import '../viewmodels/app_viewmodel.dart';

// ──────────────────────────────────────────────────────
// Calendar ViewModel
// ──────────────────────────────────────────────────────
final calendarEventsProvider = AsyncNotifierProvider.autoDispose<
    CalendarEventsNotifier, List<goog_cal.Event>>(
  CalendarEventsNotifier.new,
);

class CalendarEventsNotifier extends AsyncNotifier<List<goog_cal.Event>> {
  @override
  Future<List<goog_cal.Event>> build() async {
    final repo = ref.watch(calendarRepositoryProvider);
    if (repo == null) return [];
    final timezone =
        ref.watch(settingsProvider).value?.timezone ?? 'Asia/Seoul';
    return await repo.fetchEvents(timezone: timezone);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(calendarRepositoryProvider);
      if (repo == null) return [];
      final timezone =
          ref.read(settingsProvider).value?.timezone ?? 'Asia/Seoul';
      return await repo.fetchEvents(timezone: timezone);
    });
  }

  Future<void> createEvent({
    required String summary,
    String? description,
    required DateTime start,
    required DateTime end,
    required String timezone,
    String? colorId,
  }) async {
    final repo = ref.read(calendarRepositoryProvider);
    if (repo == null) return;
    await repo.createEvent(
      summary: summary,
      description: description,
      start: start,
      end: end,
      timezone: timezone,
      colorId: colorId,
    );
    await refresh();
  }

  Future<void> deleteEvent(String eventId) async {
    final repo = ref.read(calendarRepositoryProvider);
    if (repo == null) return;
    await repo.deleteEvent(eventId);
    await refresh();
  }
}
