import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/calendar/v3.dart' as goog_cal;

import '../../data/repositories/calendar_repository.dart';
import '../viewmodels/app_viewmodel.dart';

// ──────────────────────────────────────────────────────
// Calendar ViewModel
// ──────────────────────────────────────────────────────
final calendarEventsProvider = AsyncNotifierProvider.autoDispose<
    CalendarEventsNotifier, List<goog_cal.Event>>(
  CalendarEventsNotifier.new,
);

class CalendarEventsNotifier extends AsyncNotifier<List<goog_cal.Event>> {
  DateTime? _visibleFrom;
  DateTime? _visibleTo;
  int _requestId = 0;

  @override
  Future<List<goog_cal.Event>> build() async {
    final repo = ref.watch(calendarRepositoryProvider);
    if (repo == null) return [];
    final timezone =
        ref.watch(settingsProvider).value?.timezone ?? 'Asia/Seoul';
    return await repo.fetchEvents(timezone: timezone);
  }

  Future<void> refresh() async {
    final repo = ref.read(calendarRepositoryProvider);
    if (repo == null) {
      state = const AsyncData([]);
      return;
    }
    final timezone = ref.read(settingsProvider).value?.timezone ?? 'Asia/Seoul';
    await _loadEvents(
      repo: repo,
      timezone: timezone,
      from: _visibleFrom,
      to: _visibleTo,
    );
  }

  Future<void> loadVisibleRange({
    required DateTime from,
    required DateTime to,
  }) async {
    if (_visibleFrom == from && _visibleTo == to) return;
    _visibleFrom = from;
    _visibleTo = to;
    final repo = ref.read(calendarRepositoryProvider);
    if (repo == null) return;
    final timezone = ref.read(settingsProvider).value?.timezone ?? 'Asia/Seoul';
    await _loadEvents(
      repo: repo,
      timezone: timezone,
      from: from,
      to: to,
    );
  }

  Future<void> _loadEvents({
    required CalendarRepository repo,
    required String timezone,
    DateTime? from,
    DateTime? to,
  }) async {
    final requestId = ++_requestId;
    try {
      final events = await repo.fetchEvents(
        from: from,
        to: to,
        timezone: timezone,
      );
      if (requestId == _requestId) state = AsyncData(events);
    } catch (error, stackTrace) {
      if (requestId == _requestId) {
        state = AsyncError(error, stackTrace);
      }
    }
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
