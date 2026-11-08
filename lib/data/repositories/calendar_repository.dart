import 'package:googleapis/calendar/v3.dart' as goog_cal;
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:flutter/material.dart';

/// Google Calendar API 접근 레이어
class CalendarRepository {
  final goog_cal.CalendarApi _api;

  CalendarRepository(http.Client client) : _api = goog_cal.CalendarApi(client);

  Future<List<goog_cal.Event>> fetchEvents({
    DateTime? from,
    DateTime? to,
    int maxResults = 250,
  }) async {
    final start = from ?? DateTime.now().subtract(const Duration(days: 30));
    final end = to ?? DateTime.now().add(const Duration(days: 90));

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
    bool isAllDay = false,
  }) async {
    final event = goog_cal.Event(
      summary: summary,
      description: description,
       start: isAllDay
           ? goog_cal.EventDateTime(date: DateTime(start.year, start.month, start.day))
           : goog_cal.EventDateTime(dateTime: start.toUtc()),
       end: isAllDay
           ? goog_cal.EventDateTime(date: DateTime(end.year, end.month, end.day))
           : goog_cal.EventDateTime(dateTime: end.toUtc()),
    );
    return await _api.events.insert(event, 'primary');
  }

  Future<void> deleteEvent(String eventId) =>
      _api.events.delete('primary', eventId);
}

/// Google Calendar Event → Syncfusion Appointment 변환 어댑터
class GoogleCalendarDataSource extends CalendarDataSource {
  final Color eventColor;

  GoogleCalendarDataSource(List<goog_cal.Event> events,
      {this.eventColor = Colors.indigo}) {
    appointments = events
        .map((e) => _toAppointment(e, eventColor))
        .whereType<Appointment>()
        .toList();
  }

  static Appointment? _toAppointment(goog_cal.Event e, Color color) {
    DateTime start;
    DateTime end;
    bool isAllDay = false;

    if (e.start?.dateTime != null) {
      start = e.start!.dateTime!.toLocal();
     } else if (e.start?.date != null) {
       start = e.start!.date!.toLocal();
       isAllDay = true;
     } else {
      return null;
    }

    if (e.end?.dateTime != null) {
      end = e.end!.dateTime!.toLocal();
     } else if (e.end?.date != null) {
       end = e.end!.date!.toLocal();
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
      color: color,
    );
  }
}
