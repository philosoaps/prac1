import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as goog_cal;
import '../../../core/utils/app_timezone.dart';
import '../../../data/models/time_category_model.dart';
import 'calendar_layout.dart';

/// 일 단위 시간별 테이블 뷰
class DayView extends StatelessWidget {
  final List<goog_cal.Event> events;
  final DateTime selectedDate;
  final Color themeColor;
  final bool startOnSunday;
  final String timezone;
  final ValueCallback<goog_cal.Event> onEventTap;
  final ValueCallback<DateTime> onDateTap;

  const DayView({
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
    final dayEvents = <int, List<goog_cal.Event>>{};
    for (final e in events) {
      final s = e.start?.dateTime ?? e.start?.date;
      final e2 = e.end?.dateTime ?? e.end?.date;
      if (s == null || e2 == null) continue;
      final localStart = dateInTimezone(s, timezone);
      final localEnd = dateInTimezone(e2, timezone);
      final d = selectedDate;
      final lastHour = localEnd.minute == 0 ? localEnd.hour - 1 : localEnd.hour;
      if (d.year == localStart.year &&
          d.month == localStart.month &&
          d.day == localStart.day) {
        for (int h = localStart.hour; h <= lastHour; h++) {
          dayEvents.putIfAbsent(h, () => []);
          dayEvents[h]!.add(e);
        }
      }
    }

    return Padding(
      padding: EdgeInsets.zero,
      child: ListView.builder(
        itemCount: 24,
        itemBuilder: (context, hour) {
          return _DayTimeRow(
            hour: hour,
            selectedDate: selectedDate,
            dayEvents: dayEvents[hour] ?? [],
            timezone: timezone,
            themeColor: themeColor,
            onEventTap: onEventTap,
            onDateTap: onDateTap,
          );
        },
      ),
    );
  }
}

class _DayTimeRow extends StatelessWidget {
  final int hour;
  final DateTime selectedDate;
  final List<goog_cal.Event> dayEvents;
  final String timezone;
  final Color themeColor;
  final ValueCallback<goog_cal.Event> onEventTap;
  final ValueCallback<DateTime> onDateTap;

  const _DayTimeRow({
    required this.hour,
    required this.selectedDate,
    required this.dayEvents,
    required this.timezone,
    required this.themeColor,
    required this.onEventTap,
    required this.onDateTap,
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
          // 시간 라벨
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
          // 단일 날짜 셀
          Expanded(
            child: GestureDetector(
              onTap: () => onDateTap(selectedDate),
              child: Container(
                color: themeColor.withAlpha(20),
                child: Stack(
                  children: [
                    ...dayEvents.map((e) => _DayEventBlock(
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
          ),
        ],
      ),
    );
  }
}

class _DayEventBlock extends StatelessWidget {
  final goog_cal.Event event;
  final int hour;
  final String timezone;
  final Color themeColor;
  final VoidCallback onTap;

  const _DayEventBlock({
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
    final top = (segmentStartMinute / 60) * _DayTimeRow.slotHeight;
    var height =
        ((segmentEndMinute - segmentStartMinute) / 60) * _DayTimeRow.slotHeight;
    height = height.clamp(0.0, _DayTimeRow.slotHeight - top);

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

typedef ValueCallback<T> = void Function(T);
