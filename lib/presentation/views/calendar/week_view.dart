import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as goog_cal;
import '../../../core/utils/app_timezone.dart';
import '../../../data/models/time_category_model.dart';
import 'calendar_layout.dart';

/// 주 단위 시간별 테이블 뷰
class WeekView extends StatelessWidget {
  final List<goog_cal.Event> events;
  final DateTime selectedDate;
  final Color themeColor;
  final bool startOnSunday;
  final String timezone;
  final ValueCallback<goog_cal.Event> onEventTap;
  final ValueCallback<DateTime> onDateTap;

  const WeekView({
    super.key,
    required this.events,
    required this.selectedDate,
    required this.themeColor,
    required this.startOnSunday,
    required this.timezone,
    required this.onEventTap,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final weekStart = _startOfWeek(selectedDate, startOnSunday);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    final hourEvents = <int, Map<int, List<goog_cal.Event>>>{};
    for (final e in events) {
      final s = e.start?.dateTime ?? e.start?.date;
      final e2 = e.end?.dateTime ?? e.end?.date;
      if (s == null || e2 == null) continue;
      final localStart = dateInTimezone(s, timezone);
      final localEnd = dateInTimezone(e2, timezone);
      final lastHour = localEnd.minute == 0 ? localEnd.hour - 1 : localEnd.hour;
      for (int h = localStart.hour; h <= lastHour; h++) {
        for (final d in weekDays) {
          if (d.year == localStart.year &&
              d.month == localStart.month &&
              d.day == localStart.day &&
              h >= localStart.hour &&
              h <= lastHour) {
            hourEvents.putIfAbsent(h, () => {});
            hourEvents[h]!.putIfAbsent(d.weekday % 7, () => []);
            hourEvents[h]![d.weekday % 7]!.add(e);
          }
        }
      }
    }

    return Padding(
      padding: EdgeInsets.zero,
      child: ListView.builder(
        itemCount: 24,
        itemBuilder: (context, hour) {
          return _TimeRow(
            hour: hour,
            weekDays: weekDays,
            eventsBySlot: hourEvents[hour] ?? {},
            timezone: timezone,
            themeColor: themeColor,
            onEventTap: onEventTap,
            onDateTap: onDateTap,
            selectedDate: selectedDate,
          );
        },
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final int hour;
  final List<DateTime> weekDays;
  final Map<int, List<goog_cal.Event>> eventsBySlot;
  final String timezone;
  final Color themeColor;
  final ValueCallback<goog_cal.Event> onEventTap;
  final ValueCallback<DateTime> onDateTap;
  final DateTime selectedDate;

  const _TimeRow({
    required this.hour,
    required this.weekDays,
    required this.eventsBySlot,
    required this.timezone,
    required this.themeColor,
    required this.onEventTap,
    required this.onDateTap,
    required this.selectedDate,
  });

  static const double slotHeight = 52;

  @override
  Widget build(BuildContext context) {
    final timeLabel = hour.toString().padLeft(2, '0');
    return Container(
      height: slotHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(30))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 시간 라벨 (왼쪽)
          SizedBox(
            width: CalendarLayout.leftRailWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: themeColor,
                ),
              ),
            ),
          ),
          // 요일 셀들
          ...List.generate(7, (i) {
            final d = weekDays[i];
            final dayEvents = eventsBySlot[d.weekday % 7] ?? [];
            final isToday = d.year == selectedDate.year &&
                d.month == selectedDate.month &&
                d.day == selectedDate.day;
            return Expanded(
              child: GestureDetector(
                onTap: () => onDateTap(d),
                child: Container(
                  color: isToday ? themeColor.withAlpha(20) : null,
                  child: Stack(
                    children: [
                      ...dayEvents.map((e) => _EventBlock(
                            event: e,
                            hour: hour,
                            timezone: timezone,
                            themeColor: themeColor,
                            onTap: () => onEventTap(e),
                          )),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _EventBlock extends StatelessWidget {
  final goog_cal.Event event;
  final int hour;
  final String timezone;
  final Color themeColor;
  final VoidCallback onTap;

  const _EventBlock({
    required this.event,
    required this.hour,
    required this.timezone,
    required this.themeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = event.start?.dateTime ?? event.start?.date;
    final e = event.end?.dateTime ?? event.end?.date;
    if (s == null || e == null) return const SizedBox.shrink();

    final localStart = dateInTimezone(s, timezone);
    final localEnd = dateInTimezone(e, timezone);

    final segmentStartMinute = hour == localStart.hour ? localStart.minute : 0;
    final segmentEndMinute = hour == localEnd.hour ? localEnd.minute : 60;
    final top = (segmentStartMinute / 60) * _TimeRow.slotHeight;
    var height =
        ((segmentEndMinute - segmentStartMinute) / 60) * _TimeRow.slotHeight;
    height = height.clamp(0.0, _TimeRow.slotHeight - top);

    final category = TimeCategoryDetails.fromGoogleColorId(event.colorId) ??
        TimeCategory.system;

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Color.lerp(Colors.white, category.color, 0.28),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: category.color.withAlpha(150), width: 1),
          ),
          child: hour == localStart.hour && height >= 16
              ? Center(
                  child: Text(
                    event.summary ?? '(제목 없음)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// ValueCallback typedef (Dart 3 compat)
typedef ValueCallback<T> = void Function(T);

/// 주 시작일 (일/월 시작 설정 반영)
DateTime _startOfWeek(DateTime d, bool startOnSunday) {
  final wd = d.weekday;
  final offset = startOnSunday ? (wd == 7 ? 0 : wd) : wd - 1;
  return DateTime(d.year, d.month, d.day).subtract(Duration(days: offset));
}
