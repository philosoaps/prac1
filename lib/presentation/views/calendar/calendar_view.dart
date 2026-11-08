import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:googleapis/calendar/v3.dart' as goog_cal;

import '../../../core/utils/app_timezone.dart';
import '../../../data/models/time_category_model.dart';
import '../../viewmodels/app_viewmodel.dart';
import '../../viewmodels/calendar_viewmodel.dart';
import '../../../data/repositories/calendar_repository.dart';

/// Syncfusion Calendar 뷰 (월/주/일)
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _ViewMode _mode = _ViewMode.month;
  DateTime _selectedDate = DateTime.now();
  Offset? _pointerStart;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(calendarEventsProvider);
    final settings = ref.watch(settingsProvider).value;
    final themeColor = settings?.themeColor ?? Colors.indigo;
    final startOnSunday = settings?.startOnSunday ?? true;
    final isKo = settings?.language != 'en';
    final timezone = settings?.timezone ?? 'Asia/Seoul';
    final selectedDate = dateInTimezone(_selectedDate, timezone);

    final sfView = switch (_mode) {
      _ViewMode.month => CalendarView.month,
      _ViewMode.week => CalendarView.week,
      _ViewMode.day => CalendarView.day,
    };

    return Scaffold(
      body: Column(
        children: [
          // ── 뷰 모드 세그먼트 버튼 ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<_ViewMode>(
              segments: [
                ButtonSegment(
                  value: _ViewMode.month,
                  label: Text(isKo ? '월' : 'Month'),
                ),
                ButtonSegment(
                  value: _ViewMode.week,
                  label: Text(isKo ? '주' : 'Week'),
                ),
                ButtonSegment(
                  value: _ViewMode.day,
                  label: Text(isKo ? '일' : 'Day'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => _changeMode(s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          // ── 캘린더 본체 ───────────────────────────────────
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
                data: (events) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.035),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(_mode),
                    children: [
                      if (_mode == _ViewMode.day)
                        _SelectedDateHeader(
                          date: selectedDate,
                          isKo: isKo,
                          color: themeColor,
                        ),
                      Expanded(
                        child: SfCalendar(
                          key: ValueKey('calendar-$_mode'),
                          view: sfView,
                          initialDisplayDate: selectedDate,
                          initialSelectedDate: selectedDate,
                          firstDayOfWeek: startOnSunday ? 7 : 1,
                          dataSource: GoogleCalendarDataSource(
                            events,
                            eventColor: themeColor,
                            timezone: timezone,
                          ),
                          viewHeaderHeight: _mode == _ViewMode.day ? 0 : 40,
                          timeSlotViewSettings: const TimeSlotViewSettings(
                            timeIntervalHeight: 52,
                          ),
                          monthViewSettings: const MonthViewSettings(
                            appointmentDisplayMode:
                                MonthAppointmentDisplayMode.appointment,
                            showAgenda: false,
                          ),
                          headerStyle: CalendarHeaderStyle(
                            textStyle: TextStyle(
                              color: themeColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          todayHighlightColor: themeColor,
                          selectionDecoration: BoxDecoration(
                            color: themeColor.withAlpha(30),
                            border: Border.all(color: themeColor, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onTap: (details) =>
                              _onTap(context, ref, details, events),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'cal_fab',
        child: const Icon(Icons.add),
        onPressed: () => _showCreateEventDialog(
          context,
          ref,
          selectedDate,
          timezone,
        ),
      ),
    );
  }

  void _handleSwipe(Offset end) {
    final start = _pointerStart;
    _pointerStart = null;
    if (start == null) return;
    final delta = end - start;
    if (delta.dy.abs() < 70 || delta.dy.abs() < delta.dx.abs() * 1.25) return;
    if (delta.dy < 0) {
      _changeMode(switch (_mode) {
        _ViewMode.day => _ViewMode.week,
        _ViewMode.week => _ViewMode.month,
        _ViewMode.month => _ViewMode.month,
      });
    } else {
      _changeMode(switch (_mode) {
        _ViewMode.month => _ViewMode.week,
        _ViewMode.week => _ViewMode.day,
        _ViewMode.day => _ViewMode.day,
      });
    }
  }

  void _changeMode(_ViewMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
  }

  void _onTap(
    BuildContext context,
    WidgetRef ref,
    CalendarTapDetails details,
    List<goog_cal.Event> events,
  ) {
    if (details.targetElement == CalendarElement.appointment) {
      final appt = details.appointments?.first as Appointment?;
      if (appt == null) return;
      _showEventDetailDialog(context, ref, appt, events);
    } else if (details.targetElement == CalendarElement.calendarCell ||
        details.targetElement == CalendarElement.allDayPanel) {
      final date = details.date ?? _selectedDate;
      setState(() => _selectedDate = date);
    }
  }

  void _showEventDetailDialog(
    BuildContext context,
    WidgetRef ref,
    Appointment appt,
    List<goog_cal.Event> events,
  ) {
    final eventId = appt.id as String?;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appt.subject),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              icon: Icons.access_time,
              text: appt.isAllDay
                  ? '종일'
                  : '${_fmt(appt.startTime)} – ${_fmt(appt.endTime)}',
            ),
            if (TimeCategoryDetails.fromGoogleColorId(events
                    .where((event) => event.id == eventId)
                    .firstOrNull
                    ?.colorId)
                case final category?)
              _DetailRow(
                icon: Icons.circle,
                text: category.labelKo,
                color: category.color,
              ),
            if (appt.notes != null && appt.notes!.isNotEmpty)
              _DetailRow(icon: Icons.notes, text: appt.notes!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
          if (eventId != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(calendarEventsProvider.notifier)
                    .deleteEvent(eventId);
              },
              child: const Text('삭제'),
            ),
        ],
      ),
    );
  }

  void _showCreateEventDialog(
    BuildContext context,
    WidgetRef ref,
    DateTime initialDate,
    String timezone,
  ) {
    showDialog(
      context: context,
      builder: (_) => _CreateEventDialog(
        ref: ref,
        initialDate: initialDate,
        timezone: timezone,
      ),
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── 뷰 모드 열거형 ───────────────────────────────────────
enum _ViewMode { month, week, day }

class _SelectedDateHeader extends StatelessWidget {
  const _SelectedDateHeader({
    required this.date,
    required this.isKo,
    required this.color,
  });

  final DateTime date;
  final bool isKo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final weekday = isKo
        ? ['월', '화', '수', '목', '금', '토', '일'][date.weekday - 1]
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: SizedBox(
        width: 58,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            border: Border.all(color: color.withAlpha(100)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              children: [
                Text(
                  weekday,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 이벤트 상세 행 ────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _DetailRow({
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

// ── 이벤트 생성 다이얼로그 ───────────────────────────────
class _CreateEventDialog extends StatefulWidget {
  final WidgetRef ref;
  final DateTime initialDate;
  final String timezone;

  const _CreateEventDialog({
    required this.ref,
    required this.initialDate,
    required this.timezone,
  });

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TimeCategory _category = TimeCategory.system;
  late DateTime _start;
  late DateTime _end;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = nowInTimezone(widget.timezone);
    final base = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
      now.hour,
      now.minute,
    );
    _start = wallTimeInTimezone(base, widget.timezone);
    _end = _start.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 이벤트'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '제목 *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: '설명 (선택)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TimeCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: '시간 카테고리',
                border: OutlineInputBorder(),
              ),
              items: TimeCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 14, color: category.color),
                          const SizedBox(width: 8),
                          Text(category.labelKo),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (category) {
                if (category != null) setState(() => _category = category);
              },
            ),
            const SizedBox(height: 12),
            _TimeRow(
              label: '시작',
              dt: _start,
              onPick: (dt) => setState(() {
                _start = wallTimeInTimezone(dt, widget.timezone);
                if (_end.isBefore(_start)) {
                  _end = _start.add(const Duration(hours: 1));
                }
              }),
            ),
            const SizedBox(height: 8),
            _TimeRow(
              label: '종료',
              dt: _end,
              onPick: (dt) => setState(
                () => _end = wallTimeInTimezone(dt, widget.timezone),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : FilledButton(
                onPressed: _submit,
                child: const Text('만들기'),
              ),
      ],
    );
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _loading = true);
    await widget.ref.read(calendarEventsProvider.notifier).createEvent(
          summary: title,
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          start: _start,
          end: _end,
          timezone: widget.timezone,
          colorId: _category.googleColorId,
        );
    if (mounted) Navigator.pop(context);
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final DateTime dt;
  final ValueChanged<DateTime> onPick;
  const _TimeRow({required this.label, required this.dt, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 36,
            child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: dt,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d == null) return;
              if (!context.mounted) return;
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(dt),
              );
              if (!context.mounted) return;
              onPick(DateTime(d.year, d.month, d.day, t?.hour ?? dt.hour,
                  t?.minute ?? dt.minute));
            },
            child: Text(_fmtDt(dt), style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  String _fmtDt(DateTime d) {
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
