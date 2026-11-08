import 'package:prac1/core/utils/app_timezone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prac1/data/models/time_category_model.dart';
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
}
