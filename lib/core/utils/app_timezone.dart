import 'package:timezone/timezone.dart' as tz;

tz.TZDateTime nowInTimezone(String timezone) =>
    tz.TZDateTime.now(tz.getLocation(timezone));

tz.TZDateTime dateInTimezone(DateTime date, String timezone) =>
    tz.TZDateTime.from(date, tz.getLocation(timezone));

tz.TZDateTime wallTimeInTimezone(DateTime date, String timezone) =>
    tz.TZDateTime(
      tz.getLocation(timezone),
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
    );
