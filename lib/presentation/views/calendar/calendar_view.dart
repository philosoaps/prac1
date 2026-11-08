import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/calendar/v3.dart' as goog_cal;

import '../../../core/utils/app_timezone.dart';
import '../../../data/models/time_category_model.dart';
import '../../viewmodels/app_viewmodel.dart';
import '../../viewmodels/calendar_viewmodel.dart';
import '../../widgets/schedule_task_composer.dart';
import 'calendar_layout.dart';
import 'week_view.dart';
import 'day_view.dart';
import 'continuous_calendar_view.dart';

/// Calendar views with a shared fixed week header.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _ViewMode _mode = _ViewMode.month;
  Offset? _pointerStart;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(calendarEventsProvider);
    final selectedDateState = ref.watch(selectedCalendarDateProvider);
    final settings = ref.watch(settingsProvider).value;
    final themeColor = settings?.themeColor ?? Colors.indigo;
    final startOnSunday = settings?.startOnSunday ?? true;
    final isKo = settings?.language != 'en';
    final timezone = settings?.timezone ?? 'Asia/Seoul';
    final selectedDate = dateInTimezone(selectedDateState, timezone);
    return Scaffold(
      body: Column(
        children: [
          // ── 뷰 모드 세그먼트 (체크 없음, 색상으로만 구별) ────
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
            child: _ModeSelector(
              mode: _mode,
              themeColor: themeColor,
              isKo: isKo,
              onChanged: (m) => _changeMode(m),
            ),
          ),
          // ── 캘린더 헤더 (월 라벨 + 요일 + 주 날짜 행, 고정) ────
          _CalendarHeader(
            selectedDate: selectedDate,
            themeColor: themeColor,
            isKo: isKo,
            startOnSunday: startOnSunday,
            mode: _mode,
            onDateTap: (date) {
              if (_mode == _ViewMode.continuous) {
                ref.read(selectedCalendarDateProvider.notifier).select(date);
              } else {
                _selectDate(date, timezone, startOnSunday);
              }
            },
            onWeekSwipe: (direction) =>
                _navigateByWeek(direction, timezone, startOnSunday),
          ),
          // ── 캘린더 본체 (스크롤 영역) ────────────────────────
          Expanded(
            child: Listener(
              onPointerDown: (event) => _pointerStart = event.position,
              onPointerUp: (event) => _handleSwipe(event.position),
              onPointerCancel: (_) => _pointerStart = null,
              child: eventsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(
                        isKo ? '오류: $e' : 'Error: $e',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.refresh(calendarEventsProvider),
                        child: Text(isKo ? '다시 시도' : 'Retry'),
                      ),
                    ],
                  ),
                ),
                data: (events) => switch (_mode) {
                  _ViewMode.month => _MonthGridView(
                      events: events,
                      selectedDate: selectedDate,
                      themeColor: themeColor,
                      startOnSunday: startOnSunday,
                      timezone: timezone,
                      onDateTap: (date) =>
                          _selectDate(date, timezone, startOnSunday),
                      onEventTap: (event) =>
                          _onEventTap(context, ref, event, timezone),
                      onVisibleRange: (from, to) => ref
                          .read(calendarEventsProvider.notifier)
                          .loadVisibleRange(
                            from: wallTimeInTimezone(from, timezone),
                            to: wallTimeInTimezone(to, timezone),
                          ),
                    ),
                  _ViewMode.week => WeekView(
                      events: events,
                      selectedDate: selectedDate,
                      themeColor: themeColor,
                      startOnSunday: startOnSunday,
                      timezone: timezone,
                      onEventTap: (event) => _onEventTap(
                        context,
                        ref,
                        event,
                        timezone,
                      ),
                      onDateTap: (date) =>
                          _selectDate(date, timezone, startOnSunday),
                      key: ValueKey(
                        'week-${selectedDate.year}-${selectedDate.month}-${selectedDate.day}',
                      ),
                    ),
                  _ViewMode.day => DayView(
                      events: events,
                      selectedDate: selectedDate,
                      themeColor: themeColor,
                      startOnSunday: startOnSunday,
                      timezone: timezone,
                      onEventTap: (event) => _onEventTap(
                        context,
                        ref,
                        event,
                        timezone,
                      ),
                      onDateTap: (date) =>
                          _selectDate(date, timezone, startOnSunday),
                      key: ValueKey(
                        'day-${selectedDate.year}-${selectedDate.month}-${selectedDate.day}',
                      ),
                    ),
                  _ViewMode.continuous => ContinuousCalendarView(
                      events: events,
                      selectedDate: selectedDate,
                      themeColor: themeColor,
                      startOnSunday: startOnSunday,
                      timezone: timezone,
                      onEventTap: (event) => _onEventTap(
                        context,
                        ref,
                        event,
                        timezone,
                      ),
                      onDateTap: (date) => ref
                          .read(selectedCalendarDateProvider.notifier)
                          .select(date),
                      onWindowChanged: (from, to) => ref
                          .read(calendarEventsProvider.notifier)
                          .loadVisibleRange(
                            from: wallTimeInTimezone(from, timezone),
                            to: wallTimeInTimezone(to, timezone),
                          ),
                    ),
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'cal_fab',
        child: const Icon(Icons.add),
        onPressed: () => showScheduleTaskEntryMenu(
          context: context,
          ref: ref,
          initialDate: selectedDate,
          timezone: timezone,
        ),
      ),
    );
  }

  void _handleSwipe(Offset end) {
    final start = _pointerStart;
    _pointerStart = null;
    if (start == null) return;
    final delta = end - start;
    if (delta.dx.abs() >= 70 && delta.dx.abs() > delta.dy.abs() * 1.25) {
      _navigateByWeek(delta.dx < 0 ? 1 : -1, null, null);
      return;
    }
  }

  void _selectDate(
    DateTime date,
    String? timezone,
    bool? startOnSunday,
  ) {
    ref.read(selectedCalendarDateProvider.notifier).select(date);
    if (timezone == null || startOnSunday == null) return;
    final range = switch (_mode) {
      _ViewMode.month => _monthRange(date, startOnSunday),
      _ViewMode.week => (
          _startOfWeek(date, startOnSunday),
          _startOfWeek(date, startOnSunday).add(const Duration(days: 7)),
        ),
      _ViewMode.day => (
          DateTime(date.year, date.month, date.day),
          DateTime(date.year, date.month, date.day)
              .add(const Duration(days: 1)),
        ),
      _ViewMode.continuous => (
          _startOfWeek(date, startOnSunday),
          _startOfWeek(date, startOnSunday).add(const Duration(days: 14)),
        ),
    };
    ref.read(calendarEventsProvider.notifier).loadVisibleRange(
          from: wallTimeInTimezone(range.$1, timezone),
          to: wallTimeInTimezone(range.$2, timezone),
        );
  }

  void _navigateByWeek(
    int direction,
    String? timezone,
    bool? startOnSunday,
  ) {
    final settings = ref.read(settingsProvider).value;
    final zone = timezone ?? settings?.timezone ?? 'Asia/Seoul';
    final sunday = startOnSunday ?? settings?.startOnSunday ?? true;
    final selected = dateInTimezone(
      ref.read(selectedCalendarDateProvider),
      zone,
    );
    final weekStart =
        _startOfWeek(selected, sunday).add(Duration(days: 7 * direction));
    _selectDate(weekStart, zone, sunday);
  }

  void _changeMode(_ViewMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
  }

  void _onEventTap(
    BuildContext context,
    WidgetRef ref,
    goog_cal.Event event,
    String timezone,
  ) {
    final appointmentDate = event.start?.dateTime ?? event.start?.date;
    if (appointmentDate == null) return;
    ref.read(selectedCalendarDateProvider.notifier).select(appointmentDate);
    showDialog<void>(
      context: context,
      builder: (_) => ScheduleTaskComposer(
        initialDate: appointmentDate,
        timezone: timezone,
        schedule: event,
      ),
    );
  }
}

// ── 뷰 모드 열거형 ───────────────────────────────────────
enum _ViewMode { month, week, day, continuous }

// ── 모드 선택 버튼 (체크 없음, 배경색으로만 구별) ─────────
class _ModeSelector extends StatelessWidget {
  final _ViewMode mode;
  final Color themeColor;
  final bool isKo;
  final ValueChanged<_ViewMode> onChanged;

  const _ModeSelector({
    required this.mode,
    required this.themeColor,
    required this.isKo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ModePill(
          label: isKo ? '월' : 'Month',
          value: _ViewMode.month,
          selected: mode == _ViewMode.month,
          themeColor: themeColor,
          onTap: () => onChanged(_ViewMode.month),
        ),
        const SizedBox(width: 6),
        _ModePill(
          label: isKo ? '주' : 'Week',
          value: _ViewMode.week,
          selected: mode == _ViewMode.week,
          themeColor: themeColor,
          onTap: () => onChanged(_ViewMode.week),
        ),
        const SizedBox(width: 6),
        _ModePill(
          label: isKo ? '일' : 'Day',
          value: _ViewMode.day,
          selected: mode == _ViewMode.day,
          themeColor: themeColor,
          onTap: () => onChanged(_ViewMode.day),
        ),
        const SizedBox(width: 6),
        _ModePill(
          label: isKo ? '연속' : 'Continuous',
          value: _ViewMode.continuous,
          selected: mode == _ViewMode.continuous,
          themeColor: themeColor,
          onTap: () => onChanged(_ViewMode.continuous),
        ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final _ViewMode value;
  final bool selected;
  final Color themeColor;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.value,
    required this.selected,
    required this.themeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? themeColor : Colors.transparent,
          border: Border.all(
            color: selected ? themeColor : themeColor.withAlpha(60),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : themeColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── 캘린더 헤더: 월 라벨(진한 볼드) + 요일 행 + 주 날짜 행 (고정) ──
class _CalendarHeader extends StatelessWidget {
  final DateTime selectedDate;
  final Color themeColor;
  final bool isKo;
  final bool startOnSunday;
  final _ViewMode mode;
  final void Function(DateTime) onDateTap;
  final void Function(int) onWeekSwipe;

  const _CalendarHeader({
    required this.selectedDate,
    required this.themeColor,
    required this.isKo,
    required this.startOnSunday,
    required this.mode,
    required this.onDateTap,
    required this.onWeekSwipe,
  });

  @override
  Widget build(BuildContext context) {
    final weekStart = _startOfWeek(selectedDate, startOnSunday);
    final monthLabel = _monthName3(selectedDate.month, isKo);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() > 100) onWeekSwipe(velocity < 0 ? 1 : -1);
      },
      child: Container(
        color: themeColor.withAlpha(10),
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: CalendarLayout.leftRailWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      monthLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                  ),
                ),
                ...List.generate(7, (i) {
                  final d = weekStart.add(Duration(days: i));
                  return Expanded(
                    child: Center(
                      child: Text(
                        _weekdayShort(d.weekday, isKo),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: themeColor,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            if (mode != _ViewMode.month) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: CalendarLayout.leftRailWidth,
                    child: Center(
                      child: Text(
                        '${_weekOfYear(weekStart, startOnSunday)}',
                        style: TextStyle(
                          color: themeColor.withAlpha(180),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  ...List.generate(7, (i) {
                    final d = weekStart.add(Duration(days: i));
                    final isSelected = d.year == selectedDate.year &&
                        d.month == selectedDate.month &&
                        d.day == selectedDate.day;
                    return Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: () => onDateTap(d),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: isSelected
                                ? BoxDecoration(
                                    color: themeColor.withAlpha(35),
                                    borderRadius: BorderRadius.circular(6),
                                  )
                                : null,
                            child: Text(
                              '${d.day}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: themeColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _weekdayShort(int weekday, bool isKo) {
  const ko = ['일', '월', '화', '수', '목', '금', '토'];
  const en = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
  final list = isKo ? ko : en;
  return list[weekday % 7];
}

String _monthName3(int m, bool isKo) {
  const ko = [
    '1월',
    '2월',
    '3월',
    '4월',
    '5월',
    '6월',
    '7월',
    '8월',
    '9월',
    '10월',
    '11월',
    '12월'
  ];
  const en = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return (isKo ? ko : en)[m - 1];
}

/// 주 시작일 (일/월 시작 설정 반영)
DateTime _startOfWeek(DateTime d, bool startOnSunday) {
  final wd = d.weekday; // 1=월 ... 7=일
  final offset = startOnSunday ? (wd == 7 ? 0 : wd) : wd - 1;
  return DateTime(d.year, d.month, d.day).subtract(Duration(days: offset));
}

DateTime _monthGridStart(DateTime date, bool startOnSunday) =>
    _startOfWeek(DateTime(date.year, date.month, 1), startOnSunday);

(DateTime, DateTime) _monthRange(DateTime date, bool startOnSunday) {
  final start = _monthGridStart(date, startOnSunday);
  return (start, start.add(const Duration(days: 42)));
}

int _weekOfYear(DateTime weekStart, bool startOnSunday) {
  final weekYear = weekStart.add(const Duration(days: 3)).year;
  final firstWeek = _startOfWeek(DateTime(weekYear, 1, 1), startOnSunday);
  return weekStart.difference(firstWeek).inDays ~/ 7 + 1;
}

// ── 월 모드 (8열 월간 그리드) ─────────────────────────────
class _MonthGridView extends StatelessWidget {
  final List<goog_cal.Event> events;
  final DateTime selectedDate;
  final Color themeColor;
  final bool startOnSunday;
  final String timezone;
  final void Function(DateTime) onDateTap;
  final void Function(goog_cal.Event) onEventTap;
  final Future<void> Function(DateTime from, DateTime to) onVisibleRange;

  const _MonthGridView({
    required this.events,
    required this.selectedDate,
    required this.themeColor,
    required this.startOnSunday,
    required this.timezone,
    required this.onDateTap,
    required this.onEventTap,
    required this.onVisibleRange,
  });

  @override
  Widget build(BuildContext context) {
    final (from, to) = _monthRange(selectedDate, startOnSunday);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onVisibleRange(from, to);
    });
    final weeks = List.generate(
      6,
      (week) => List.generate(
        7,
        (day) => from.add(Duration(days: week * 7 + day)),
      ),
    );

    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(6, (weekIndex) {
          final days = weeks[weekIndex];
          final weekNumber = _weekOfYear(days.first, startOnSunday);
          final isActiveWeek = days.any((day) => _sameDay(day, selectedDate));
          return Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: CalendarLayout.leftRailWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isActiveWeek
                          ? themeColor.withAlpha(20)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.withAlpha(35)),
                        right: BorderSide(color: Colors.grey.withAlpha(35)),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$weekNumber',
                        style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                ...days.map((day) {
                  final inMonth = day.month == selectedDate.month &&
                      day.year == selectedDate.year;
                  final isSelected = _sameDay(day, selectedDate);
                  final dayEvents = events.where((event) {
                    final date = _eventStartDate(event, timezone);
                    return date != null && _sameDay(date, day);
                  }).toList()
                    ..sort((a, b) => _eventStartDate(a, timezone)!
                        .compareTo(_eventStartDate(b, timezone)!));
                  return Expanded(
                    child: InkWell(
                      onTap: () => onDateTap(day),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
                        decoration: BoxDecoration(
                          color: isSelected ? themeColor.withAlpha(34) : null,
                          border: Border(
                            bottom:
                                BorderSide(color: Colors.grey.withAlpha(35)),
                            right: BorderSide(color: Colors.grey.withAlpha(25)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: inMonth
                                      ? themeColor
                                      : themeColor.withAlpha(90),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            ...dayEvents.take(2).map((event) {
                              final category =
                                  TimeCategoryDetails.fromGoogleColorId(
                                        event.colorId,
                                      ) ??
                                      TimeCategory.system;
                              return GestureDetector(
                                onTap: () => onEventTap(event),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 2),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: category.color.withAlpha(36),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    event.summary ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: category.color,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            if (dayEvents.length > 2)
                              Text(
                                '+${dayEvents.length - 2}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: themeColor.withAlpha(150),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ),
    );
  }
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

DateTime? _eventStartDate(goog_cal.Event event, String timezone) {
  final allDay = event.start?.date;
  if (allDay != null) return DateTime(allDay.year, allDay.month, allDay.day);
  final start = event.start?.dateTime;
  return start == null ? null : dateInTimezone(start, timezone);
}
