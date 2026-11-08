import 'package:prac1/core/utils/app_timezone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prac1/data/models/time_category_model.dart';
import 'package:prac1/data/models/schedule_task_link.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar;
import 'package:timezone/data/latest.dart' as timezone_data;

void main() {
  setUpAll(timezone_data.initializeTimeZones);

  test('time categories have distinct colors and Google Calendar IDs', () {
    final colors = TimeCategory.values
        .map((category) => category.color.toARGB32())
        .toSet();
    final colorIds =
        TimeCategory.values.map((category) => category.googleColorId).toSet();

    expect(colors, hasLength(TimeCategory.values.length));
    expect(colorIds, hasLength(TimeCategory.values.length));
  });

  test('Google Calendar color IDs map back to their categories', () {
    for (final category in TimeCategory.values) {
      expect(
        TimeCategoryDetails.fromGoogleColorId(category.googleColorId),
        category,
      );
    }
    expect(TimeCategoryDetails.fromGoogleColorId('unknown'), isNull);
  });

  test('selected time zone converts wall time to the correct instant', () {
    final wallTime =
        wallTimeInTimezone(DateTime(2026, 1, 1, 9, 30), 'America/New_York');

    expect(wallTime.toUtc(), DateTime.utc(2026, 1, 1, 14, 30));
    expect(
      dateInTimezone(wallTime.toUtc(), 'America/New_York').hour,
      9,
    );
  });

  test('schedule task link is written to and read from private properties', () {
    const link = ScheduleTaskLink(taskId: 'task-1', taskName: 'Write proposal');
    final properties = link.toPrivateProperties();
    final event = google_calendar.Event(
      extendedProperties: google_calendar.EventExtendedProperties(
        private: properties,
      ),
    );

    final restored = ScheduleTaskLink.fromEvent(event);
    expect(restored.taskId, 'task-1');
    expect(restored.taskName, 'Write proposal');
    expect(
      properties,
      containsPair(ScheduleTaskLink.taskNameKey, 'Write proposal'),
    );
  });
}
