import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/calendar/v3.dart' as goog_cal;

import '../../../core/utils/app_timezone.dart';
import '../../../data/models/time_category_model.dart';
import '../../../data/models/schedule_task_link.dart';
import '../../viewmodels/app_viewmodel.dart';
import 'calendar_layout.dart';

/// 연속(Continuous) 뷰 — 카드 형식 일정 목록, 2주 단위 스크롤
class ContinuousCalendarView extends ConsumerStatefulWidget {
  final List<goog_cal.Event> events;
  final DateTime selectedDate;
  final Color themeColor;
  final bool startOnSunday;
  final String timezone;
  final ValueCallback<goog_cal.Event> onEventTap;
  final ValueCallback<DateTime> onDateTap;
  final Future<void> Function(DateTime from, DateTime to) onWindowChanged;

  const ContinuousCalendarView({
    super.key,
    required this.events,
    required this.selectedDate,
    required this.themeColor,
    required this.startOnSunday,
    required this.timezone,
    required this.onEventTap,
    required this.onDateTap,
    required this.onWindowChanged,
  });

  @override
  ConsumerState<ContinuousCalendarView> createState() =>
      _ContinuousCalendarViewState();
}

class _ContinuousCalendarViewState
    extends ConsumerState<ContinuousCalendarView> {
  late DateTime _windowStart; // 2주 창의 시작일
  late DateTime _windowEnd; // 2주 창의 끝일 (미포함)
  final ScrollController _scrollController = ScrollController();
  static const double _cardExtent = 112;
  double _lastScrollOffset = 0;
  bool _movingWindow = false;

  @override
  void initState() {
    super.initState();
    _setWindow(widget.selectedDate);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await widget.onWindowChanged(_windowStart, _windowEnd);
      }
    });
  }

  @override
  void didUpdateWidget(ContinuousCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate.year != oldWidget.selectedDate.year ||
        widget.selectedDate.month != oldWidget.selectedDate.month ||
        widget.selectedDate.day != oldWidget.selectedDate.day) {
      final sel = widget.selectedDate;
      if (sel.isBefore(_windowStart) || !sel.isBefore(_windowEnd)) {
        _setWindow(sel);
        widget.onWindowChanged(_windowStart, _windowEnd);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) _scrollController.jumpTo(0);
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _setWindow(DateTime anchor) {
    final weekStart = _startOfWeek(anchor, widget.startOnSunday);
    _windowStart = weekStart;
    _windowEnd = weekStart.add(const Duration(days: 14));
  }

  void _onScroll() {
    if (_movingWindow || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final currentOffset = position.pixels;
    _syncHeaderForVisibleCard();
    final threshold = 60.0;
    if (currentOffset < _lastScrollOffset && currentOffset <= threshold) {
      _moveWindow(-14);
    } else if (currentOffset > _lastScrollOffset &&
        currentOffset >= position.maxScrollExtent - threshold) {
      _moveWindow(14);
    }
    _lastScrollOffset = currentOffset;
  }

  Future<void> _moveWindow(int days) async {
    if (_movingWindow) return;
    _movingWindow = true;
    final newStart = _windowStart.add(Duration(days: days));
    setState(() {
      _windowStart = newStart;
      _windowEnd = newStart.add(const Duration(days: 14));
    });
    await widget.onWindowChanged(_windowStart, _windowEnd);
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (_scrollController.hasClients) {
      final target =
          days < 0 ? _scrollController.position.maxScrollExtent : 0.0;
      _scrollController.jumpTo(target);
      _lastScrollOffset = target;
    }
    _movingWindow = false;
    _syncHeaderForVisibleCard();
  }

  void _syncHeaderForVisibleCard() {
    if (!_scrollController.hasClients) return;
    final events = _windowEvents;
    if (events.isEmpty) return;
    final index = (_scrollController.position.pixels / _cardExtent)
        .floor()
        .clamp(0, events.length - 1);
    final event = events[index];
    final start = event.start?.dateTime ?? event.start?.date;
    if (start == null) return;
    final visibleDate = event.start?.date != null
        ? DateTime(start.year, start.month, start.day)
        : dateInTimezone(start, widget.timezone);
    if (!_isSameDay(visibleDate, widget.selectedDate)) {
      widget.onDateTap(visibleDate);
    }
  }

  List<goog_cal.Event> get _windowEvents {
    final start = _windowStart;
    final end = _windowEnd;
    final list = widget.events.where((e) {
      final local = _eventStartDate(e);
      if (local == null) return false;
      return !local.isBefore(start) && local.isBefore(end);
    }).toList();
    list.sort((a, b) {
      final sa = _eventStartDate(a) ?? DateTime(1970);
      final sb = _eventStartDate(b) ?? DateTime(1970);
      return sa.compareTo(sb);
    });
    return list;
  }

  DateTime? _eventStartDate(goog_cal.Event event) {
    final allDay = event.start?.date;
    if (allDay != null) return DateTime(allDay.year, allDay.month, allDay.day);
    final start = event.start?.dateTime;
    return start == null ? null : dateInTimezone(start, widget.timezone);
  }

  @override
  Widget build(BuildContext context) {
    final events = _windowEvents;
    final isKo = ref.read(settingsProvider).value?.language != 'en';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncHeaderForVisibleCard();
    });

    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: CalendarLayout.leftRailWidth),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemExtent: _cardExtent,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: events.length < 14 ? 14 : events.length,
              itemBuilder: (context, i) {
                if (events.isEmpty) {
                  return i == 0
                      ? Center(
                          child: Text(
                            isKo ? '표시할 일정이 없습니다.' : 'No schedules to display.',
                          ),
                        )
                      : const SizedBox.shrink();
                }
                if (i >= events.length) return const SizedBox.shrink();
                return _ScheduleCard(
                  event: events[i],
                  themeColor: widget.themeColor,
                  timezone: widget.timezone,
                  isKo: isKo,
                  onTap: () => widget.onEventTap(events[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// ValueCallback typedef (Dart 3 compat)
typedef ValueCallback<T> = void Function(T);

/// 일정 카드 — 시간, 일정명, 관련 태스크, 파스텔 카테고리 색
class _ScheduleCard extends StatelessWidget {
  final goog_cal.Event event;
  final Color themeColor;
  final String timezone;
  final bool isKo;
  final VoidCallback onTap;

  const _ScheduleCard({
    required this.event,
    required this.themeColor,
    required this.timezone,
    required this.isKo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = event.start?.dateTime ?? event.start?.date;
    final e = event.end?.dateTime ?? event.end?.date;
    if (s == null) return const SizedBox.shrink();

    final localStart = dateInTimezone(s, timezone);
    final localEnd = e != null ? dateInTimezone(e, timezone) : null;

    final category = TimeCategoryDetails.fromGoogleColorId(event.colorId) ??
        TimeCategory.system;

    String timeText;
    if (event.start?.date != null) {
      timeText = isKo ? '종일' : 'All day';
    } else if (localEnd != null) {
      timeText = '${_hm(localStart)} ~ ${_hm(localEnd)}';
    } else {
      timeText = _hm(localStart);
    }

    final link = ScheduleTaskLink.fromEvent(event);
    final taskName = link.taskName.isNotEmpty
        ? link.taskName
        : (isKo ? '연결된 Task 없음' : 'No linked task');

    return SizedBox(
      height: _ContinuousCalendarViewState._cardExtent,
      child: InkWell(
        onTap: onTap,
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          elevation: 2,
          shadowColor: category.color.withAlpha(45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: category.color.withAlpha(45)),
          ),
          color: Color.lerp(Colors.white, category.color, 0.18),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            leading: Container(
              width: 6,
              decoration: BoxDecoration(
                color: category.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            title: Text(
              event.summary ?? (isKo ? '(제목 없음)' : '(No title)'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      timeText,
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: category.color.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          taskName,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: category.color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// 주 시작일 (일/월 시작 설정 반영)
DateTime _startOfWeek(DateTime d, bool startOnSunday) {
  final wd = d.weekday;
  final offset = startOnSunday ? (wd == 7 ? 0 : wd) : wd - 1;
  return DateTime(d.year, d.month, d.day).subtract(Duration(days: offset));
}
