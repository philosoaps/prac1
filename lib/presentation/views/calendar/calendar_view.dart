import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:googleapis/calendar/v3.dart' as goog_cal;

import '../../viewmodels/app_viewmodel.dart';
import '../../viewmodels/calendar_viewmodel.dart';
import '../../../data/repositories/calendar_repository.dart';

/// Syncfusion Calendar 뷰 (월/주/3일/일)
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _ViewMode _mode = _ViewMode.month;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(calendarEventsProvider);
    final settings = ref.watch(settingsProvider).value;
    final themeColor = settings?.themeColor ?? Colors.indigo;
    final startOnSunday = settings?.startOnSunday ?? true;

    final sfView = switch (_mode) {
       _ViewMode.month => CalendarView.month,
       _ViewMode.week => CalendarView.week,
       _ViewMode.threeDay => CalendarView.day,
       _ViewMode.day => CalendarView.day,
    };

    final numberOfDays = switch (_mode) {
      _ViewMode.threeDay => 3,
      _ => 1,
    };

    return Scaffold(
      body: Column(
        children: [
          // ── 뷰 모드 세그먼트 버튼 ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<_ViewMode>(
              segments: const [
                ButtonSegment(value: _ViewMode.month, label: Text('월간')),
                ButtonSegment(value: _ViewMode.week, label: Text('주간')),
                ButtonSegment(value: _ViewMode.threeDay, label: Text('3일')),
                ButtonSegment(value: _ViewMode.day, label: Text('일간')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          // ── 캘린더 본체 ───────────────────────────────────
          Expanded(
            child: eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('오류: $e', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.refresh(calendarEventsProvider),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
              data: (events) => SfCalendar(
                view: sfView,
                firstDayOfWeek: startOnSunday ? 7 : 1,
                dataSource: GoogleCalendarDataSource(events, eventColor: themeColor),
                timeSlotViewSettings: TimeSlotViewSettings(
                  numberOfDaysInView:
                      _mode == _ViewMode.threeDay ? numberOfDays : 1,
                ),
                monthViewSettings: const MonthViewSettings(
                  appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
                  showAgenda: true,
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
                onTap: (details) => _onTap(context, ref, details, events),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'cal_fab',
        child: const Icon(Icons.add),
        onPressed: () => _showCreateEventDialog(context, ref, DateTime.now()),
      ),
    );
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
      final date = details.date ?? DateTime.now();
      _showCreateEventDialog(context, ref, date);
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
  ) {
    showDialog(
      context: context,
      builder: (_) => _CreateEventDialog(ref: ref, initialDate: initialDate),
    );
  }

  String _fmt(DateTime dt) {
    final l = dt.toLocal();
    return '${l.month}/${l.day} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

// ── 뷰 모드 열거형 ───────────────────────────────────────
enum _ViewMode { month, week, threeDay, day }

// ── 이벤트 상세 행 ────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
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
  const _CreateEventDialog({required this.ref, required this.initialDate});

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final base = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
      DateTime.now().hour,
    );
    _start = base;
    _end = base.add(const Duration(hours: 1));
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
            _TimeRow(
              label: '시작',
              dt: _start,
              onPick: (dt) => setState(() {
                _start = dt;
                if (_end.isBefore(_start)) {
                  _end = _start.add(const Duration(hours: 1));
                }
              }),
            ),
            const SizedBox(height: 8),
            _TimeRow(
              label: '종료',
              dt: _end,
              onPick: (dt) => setState(() => _end = dt),
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
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
        );
    if (mounted) Navigator.pop(context);
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final DateTime dt;
  final ValueChanged<DateTime> onPick;
  const _TimeRow(
      {required this.label, required this.dt, required this.onPick});

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
              onPick(DateTime(
                  d.year, d.month, d.day, t?.hour ?? dt.hour, t?.minute ?? dt.minute));
            },
            child: Text(_fmtDt(dt),
                style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  String _fmtDt(DateTime d) {
    final l = d.toLocal();
    return '${l.month}/${l.day} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
