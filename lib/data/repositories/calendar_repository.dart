import 'package:googleapis/calendar/v3.dart' as goog_cal;
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:flutter/material.dart';

import '../../core/utils/app_timezone.dart';
import '../models/time_category_model.dart';

/// Google Calendar API 접근 레이어
class CalendarRepository {
  final goog_cal.CalendarApi _api;

  CalendarRepository(http.Client client) : _api = goog_cal.CalendarApi(client);

  Future<List<goog_cal.Event>> fetchEvents({
    DateTime? from,
    DateTime? to,
    String timezone = 'Asia/Seoul',
    int maxResults = 250,
  }) async {
    final now = nowInTimezone(timezone);
    final start = from ?? now.subtract(const Duration(days: 30));
    final end = to ?? now.add(const Duration(days: 90));

    final result = await _api.events.list(
      'primary',
      timeMin: start.toUtc(),
      timeMax: end.toUtc(),
      maxResults: maxResults,
      singleEvents: true,
      orderBy: 'startTime',
    );
    return result.items ?? [];
  }

  Future<goog_cal.Event> createEvent({
    required String summary,
    String? description,
    required DateTime start,
    required DateTime end,
    String timezone = 'Asia/Seoul',
    String? colorId,
    bool isAllDay = false,
  }) async {
    final event = goog_cal.Event(
      summary: summary,
      description: description,
      colorId: colorId,
      start: isAllDay
          ? goog_cal.EventDateTime(
              date: DateTime(start.year, start.month, start.day))
          : goog_cal.EventDateTime(
              dateTime: wallTimeInTimezone(start, timezone).toUtc(),
            ),
      end: isAllDay
          ? goog_cal.EventDateTime(date: DateTime(end.year, end.month, end.day))
          : goog_cal.EventDateTime(
              dateTime: wallTimeInTimezone(end, timezone).toUtc(),
            ),
    );
    return await _api.events.insert(event, 'primary');
  }

  Future<void> deleteEvent(String eventId) =>
      _api.events.delete('primary', eventId);
}

/// Google Calendar Event → Syncfusion Appointment 변환 어댑터
class GoogleCalendarDataSource extends CalendarDataSource {
  final Color eventColor;
  final String timezone;

  GoogleCalendarDataSource(List<goog_cal.Event> events,
      {this.eventColor = Colors.indigo, this.timezone = 'Asia/Seoul'}) {
    appointments = events
        .map((e) => _toAppointment(e, eventColor, timezone))
        .whereType<Appointment>()
        .toList();
  }

  static Appointment? _toAppointment(
    goog_cal.Event e,
    Color color,
    String timezone,
  ) {
    DateTime start;
    DateTime end;
    bool isAllDay = false;

    if (e.start?.dateTime != null) {
      start = dateInTimezone(e.start!.dateTime!, timezone);
    } else if (e.start?.date != null) {
      start = wallTimeInTimezone(e.start!.date!, timezone);
      isAllDay = true;
    } else {
      return null;
    }

    if (e.end?.dateTime != null) {
      end = dateInTimezone(e.end!.dateTime!, timezone);
    } else if (e.end?.date != null) {
      end = wallTimeInTimezone(e.end!.date!, timezone);
      isAllDay = true;
    } else {
      end = start.add(const Duration(hours: 1));
    }

    return Appointment(
      id: e.id,
      startTime: start,
      endTime: end,
      subject: e.summary ?? '(제목 없음)',
      notes: e.description,
      isAllDay: isAllDay,
      color: _eventColor(e.colorId, color),
    );
  }

  static Color _eventColor(String? colorId, Color fallback) {
    for (final category in TimeCategory.values) {
      if (category.googleColorId == colorId) return category.color;
    }
    return fallback;
  }
}
