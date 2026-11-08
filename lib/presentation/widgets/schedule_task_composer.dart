import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/calendar/v3.dart' as goog_cal;

import '../../core/utils/app_timezone.dart';
import '../../data/models/schedule_task_link.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_category_model.dart';
import '../viewmodels/app_viewmodel.dart';
import '../viewmodels/calendar_viewmodel.dart';
import '../viewmodels/tasks_viewmodel.dart';

enum ScheduleTaskEntryType { schedule, task }

Future<void> showScheduleTaskEntryMenu({
  required BuildContext context,
  required WidgetRef ref,
  required DateTime initialDate,
  required String timezone,
}) async {
  final isKo = ref.read(settingsProvider).value?.language != 'en';
  final type = await showModalBottomSheet<ScheduleTaskEntryType>(
    context: context,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(isKo ? '일정 (Schedule)' : 'Schedule'),
            onTap: () => Navigator.pop(context, ScheduleTaskEntryType.schedule),
          ),
          ListTile(
            leading: const Icon(Icons.checklist_outlined),
            title: Text(isKo ? '할 일 (Task)' : 'Task'),
            onTap: () => Navigator.pop(context, ScheduleTaskEntryType.task),
          ),
        ],
      ),
    ),
  );
  if (type == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => ScheduleTaskComposer(
      initialDate: initialDate,
      timezone: timezone,
      initialType: type,
    ),
  );
}

class ScheduleTaskComposer extends ConsumerStatefulWidget {
  const ScheduleTaskComposer({
    super.key,
    required this.initialDate,
    required this.timezone,
    this.initialType = ScheduleTaskEntryType.schedule,
    this.schedule,
    this.task,
  });

  final DateTime initialDate;
  final String timezone;
  final ScheduleTaskEntryType initialType;
  final goog_cal.Event? schedule;
  final TaskModel? task;

  @override
  ConsumerState<ScheduleTaskComposer> createState() =>
      _ScheduleTaskComposerState();
}

class _ScheduleTaskComposerState extends ConsumerState<ScheduleTaskComposer> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  late DateTime _date;
  late DateTime _start;
  late DateTime _end;
  DateTime? _taskDue;
  late ScheduleTaskEntryType _type;
  String? _selectedTaskId;
  TimeCategory _category = TimeCategory.system;
  String _recurrence = 'none';
  String _visibility = 'private';
  bool _isAllDay = false;
  bool _isBusy = true;
  bool _detailed = false;
  bool _loading = false;
  bool _returnToScheduleAfterTask = false;

  bool get _isKo => ref.read(settingsProvider).value?.language != 'en';
  bool get _isEditing => widget.schedule != null || widget.task != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    final selected = dateInTimezone(widget.initialDate, widget.timezone);
    final now = nowInTimezone(widget.timezone);
    _date = DateTime(selected.year, selected.month, selected.day);
    _start = DateTime(_date.year, _date.month, _date.day, now.hour, now.minute);
    _end = _start.add(const Duration(hours: 1));
    if (widget.task case final task?) {
      _titleController.text = task.title;
      _descriptionController.text = task.notes ?? '';
      _taskDue = task.due == null
          ? null
          : DateTime(task.due!.year, task.due!.month, task.due!.day);
    }
    if (widget.schedule case final event?) {
      _titleController.text = event.summary ?? '';
      _descriptionController.text = event.description ?? '';
      _locationController.text = event.location ?? '';
      final start = event.start?.dateTime ?? event.start?.date;
      final end = event.end?.dateTime ?? event.end?.date;
      if (start != null) {
        final localStart = event.start?.date != null
            ? DateTime(start.year, start.month, start.day)
            : dateInTimezone(start, widget.timezone);
        _date = DateTime(localStart.year, localStart.month, localStart.day);
        _start = localStart;
        if (event.start?.date != null) _isAllDay = true;
      }
      if (end != null) {
        _end = event.end?.date != null
            ? DateTime(end.year, end.month, end.day)
            : dateInTimezone(end, widget.timezone);
        if (_isAllDay) _end = _end.subtract(const Duration(days: 1));
      }
      final link = ScheduleTaskLink.fromEvent(event);
      _selectedTaskId = link.taskId.isEmpty ? null : link.taskId;
      _category = TimeCategoryDetails.fromGoogleColorId(event.colorId) ??
          TimeCategory.system;
      final recurrence = event.recurrence?.firstOrNull;
      _recurrence = recurrence == null
          ? 'none'
          : RegExp(r'FREQ=([A-Z]+)').firstMatch(recurrence)?.group(1) ?? 'none';
      _visibility = event.visibility ?? 'private';
      _isBusy = event.transparency != 'transparent';
    }
    _type = widget.task != null
        ? ScheduleTaskEntryType.task
        : widget.schedule != null
            ? ScheduleTaskEntryType.schedule
            : widget.initialType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsProvider);
    final media = MediaQuery.of(context);
    final dialogWidth = (media.size.width - 64).clamp(0.0, 520.0);
    final contentHeight =
        (media.size.height - media.viewInsets.bottom - 200).clamp(120.0, 600.0);
    final tasksAsync = ref.watch(tasksProvider);
    final allTasks = tasksAsync.value ?? const <TaskModel>[];
    final tasks = allTasks.where((task) => task.id.isNotEmpty).toList();
    final selectedTaskId = tasks.any((task) => task.id == _selectedTaskId)
        ? _selectedTaskId
        : null;

    return AlertDialog(
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: contentHeight),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: _isKo ? '제목 *' : 'Title *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? (_isKo ? '제목을 입력해 주세요.' : 'Enter a title.')
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _detailed = !_detailed),
                      icon: Icon(
                        _detailed ? Icons.expand_less : Icons.tune,
                        size: 18,
                      ),
                      label: Text(
                        _detailed
                            ? (_isKo ? '세부 입력 닫기' : 'Hide details')
                            : (_isKo ? '세부 입력' : 'More details'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_type == ScheduleTaskEntryType.schedule) ...[
                    _buildRelatedTaskField(tasksAsync, tasks),
                    const SizedBox(height: 12),
                    _datePicker(
                      label: _isKo ? '날짜' : 'Date',
                      date: _date,
                      onChanged: (date) => setState(() {
                        _date = DateTime(date.year, date.month, date.day);
                        _start = DateTime(
                          _date.year,
                          _date.month,
                          _date.day,
                          _start.hour,
                          _start.minute,
                        );
                        _end = DateTime(
                          _date.year,
                          _date.month,
                          _date.day,
                          _end.hour,
                          _end.minute,
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_isKo ? '종일 일정' : 'All day'),
                      value: _isAllDay,
                      onChanged: (value) => setState(() => _isAllDay = value),
                    ),
                    if (!_isAllDay) ...[
                      _timePickerRow(
                        label: _isKo ? '시작' : 'Start',
                        value: _start,
                        onChanged: (value) => setState(() {
                          _start = value;
                          if (!_end.isAfter(_start)) {
                            _end = _start.add(const Duration(hours: 1));
                          }
                        }),
                      ),
                      const SizedBox(height: 8),
                      _timePickerRow(
                        label: _isKo ? '종료' : 'End',
                        value: _end,
                        onChanged: (value) => setState(() => _end = value),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildCategoryField(),
                    if (_detailed) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: _isKo ? '설명' : 'Description',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: _isKo ? '장소' : 'Location',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.place_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _recurrence,
                        decoration: InputDecoration(
                          labelText: _isKo ? '반복' : 'Repeat',
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'none',
                            child: Text(_isKo ? '반복 안 함' : 'Does not repeat'),
                          ),
                          DropdownMenuItem(
                            value: 'DAILY',
                            child: Text(_isKo ? '매일' : 'Daily'),
                          ),
                          DropdownMenuItem(
                            value: 'WEEKLY',
                            child: Text(_isKo ? '매주' : 'Weekly'),
                          ),
                          DropdownMenuItem(
                            value: 'MONTHLY',
                            child: Text(_isKo ? '매월' : 'Monthly'),
                          ),
                          DropdownMenuItem(
                            value: 'YEARLY',
                            child: Text(_isKo ? '매년' : 'Yearly'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _recurrence = value);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_isKo ? '바쁨으로 표시' : 'Show as busy'),
                        value: _isBusy,
                        onChanged: (value) => setState(() => _isBusy = value),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _visibility,
                        decoration: InputDecoration(
                          labelText: _isKo ? '공개 범위' : 'Visibility',
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'private',
                            child: Text(_isKo ? '비공개' : 'Private'),
                          ),
                          DropdownMenuItem(
                            value: 'default',
                            child: Text(_isKo ? '기본값' : 'Default'),
                          ),
                          DropdownMenuItem(
                            value: 'public',
                            child: Text(_isKo ? '공개' : 'Public'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _visibility = value);
                          }
                        },
                      ),
                    ],
                  ] else ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_isKo ? '기한 설정' : 'Set a due date'),
                      value: _taskDue != null,
                      onChanged: (value) async {
                        if (!value) {
                          setState(() => _taskDue = null);
                          return;
                        }
                        final due = await _pickDate(_taskDue ?? _date);
                        if (due != null) setState(() => _taskDue = due);
                      },
                    ),
                    if (_taskDue != null)
                      _datePicker(
                        label: _isKo ? '기한' : 'Due date',
                        date: _taskDue!,
                        onChanged: (date) => setState(() => _taskDue = date),
                      ),
                    if (_detailed) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: _isKo ? '메모' : 'Notes',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                  if (_type == ScheduleTaskEntryType.schedule &&
                      tasksAsync.hasValue &&
                      tasks.isEmpty) ...[
                    const SizedBox(height: 12),
                    _NoTasksHint(
                      isKo: _isKo,
                      onCreateTask: () => setState(() {
                        _type = ScheduleTaskEntryType.task;
                        _returnToScheduleAfterTask = true;
                      }),
                    ),
                  ],
                  if (tasksAsync.hasError &&
                      _type == ScheduleTaskEntryType.schedule)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _isKo
                            ? 'Task 목록을 불러오지 못했습니다: ${tasksAsync.error}'
                            : 'Could not load tasks: ${tasksAsync.error}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        if (widget.schedule?.id case final eventId?)
          TextButton(
            onPressed: _loading ? null : () => _deleteSchedule(eventId),
            child: Text(_isKo ? '삭제' : 'Delete'),
          ),
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(_isKo ? '취소' : 'Cancel'),
        ),
        FilledButton(
          onPressed: _loading ||
                  (_type == ScheduleTaskEntryType.schedule &&
                      selectedTaskId == null)
              ? null
              : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _type == ScheduleTaskEntryType.schedule
                      ? (_isKo
                          ? (_isEditing ? 'Schedule 수정' : 'Schedule 저장')
                          : (_isEditing ? 'Update schedule' : 'Save schedule'))
                      : (_isKo
                          ? (_isEditing ? 'Task 수정' : 'Task 저장')
                          : (_isEditing ? 'Update task' : 'Save task')),
                ),
        ),
      ],
    );
  }

  Widget _buildRelatedTaskField(
    AsyncValue<List<TaskModel>> tasksAsync,
    List<TaskModel> tasks,
  ) {
    if (tasksAsync.isLoading && !tasksAsync.hasValue) {
      return const LinearProgressIndicator();
    }
    if (tasks.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: _isKo ? '연관 Task *' : 'Related task *',
          border: const OutlineInputBorder(),
        ),
        child: Text(
          _isKo ? '연결할 Task가 없습니다.' : 'No tasks available to link.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: tasks.any((task) => task.id == _selectedTaskId)
          ? _selectedTaskId
          : null,
      decoration: InputDecoration(
        labelText: _isKo ? '연관 Task *' : 'Related task *',
        helperText: _isKo
            ? 'Schedule에는 Task 연결이 필수입니다.'
            : 'A task is required for every schedule.',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.link),
      ),
      items: tasks
          .map(
            (task) => DropdownMenuItem(
              value: task.id,
              child: Text(
                task.isCompleted
                    ? '${task.title} (${_isKo ? '완료' : 'Completed'})'
                    : task.title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _selectedTaskId = value),
      validator: (value) => value == null
          ? (_isKo ? '연관 Task를 선택해 주세요.' : 'Select a related task.')
          : null,
    );
  }

  Widget _buildCategoryField() => DropdownButtonFormField<TimeCategory>(
        initialValue: _category,
        decoration: InputDecoration(
          labelText: _isKo ? '시간 카테고리' : 'Time category',
          border: const OutlineInputBorder(),
        ),
        items: TimeCategory.values
            .map(
              (category) => DropdownMenuItem(
                value: category,
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 14, color: category.color),
                    const SizedBox(width: 8),
                    Text(_isKo ? category.labelKo : category.labelEn),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _category = value);
        },
      );

  Widget _datePicker({
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onChanged,
  }) =>
      OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text('$label  ${_formatDate(date)}'),
        onPressed: () async {
          final selected = await _pickDate(date);
          if (selected != null) onChanged(selected);
        },
      );

  Widget _timePickerRow({
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) =>
      Row(
        children: [
          SizedBox(width: 58, child: Text(label)),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.access_time),
              label: Text(_formatTime(value)),
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(value),
                );
                if (time == null) return;
                onChanged(
                  DateTime(
                    _date.year,
                    _date.month,
                    _date.day,
                    time.hour,
                    time.minute,
                  ),
                );
              },
            ),
          ),
        ],
      );

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );

  String _formatDate(DateTime value) =>
      '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';

  String _formatTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    if (_type == ScheduleTaskEntryType.schedule && _selectedTaskId == null) {
      return;
    }
    if (_type == ScheduleTaskEntryType.schedule &&
        !_isAllDay &&
        !_end.isAfter(_start)) {
      _showMessage(_isKo
          ? '종료 시간은 시작 시간 이후여야 합니다.'
          : 'End time must be after start time.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_type == ScheduleTaskEntryType.task) {
        final notes =
            _detailed ? _descriptionController.text.trim() : widget.task?.notes;
        if (widget.task != null) {
          await ref.read(tasksProvider.notifier).updateTask(
                taskId: widget.task!.id,
                title: _titleController.text.trim(),
                notes: notes ?? '',
                due: _taskDue,
              );
        } else {
          final created = await ref.read(tasksProvider.notifier).createTask(
                title: _titleController.text.trim(),
                notes: notes?.isEmpty == true ? null : notes,
                due: _taskDue,
              );
          if (created == null) {
            throw StateError(
              _isKo ? 'Task 저장소를 사용할 수 없습니다.' : 'Task service is unavailable.',
            );
          }
          if (_returnToScheduleAfterTask) {
            if (!mounted) return;
            setState(() {
              _selectedTaskId = created.id;
              _type = ScheduleTaskEntryType.schedule;
              _returnToScheduleAfterTask = false;
              _titleController.clear();
              _descriptionController.clear();
            });
            _showMessage(
              _isKo
                  ? 'Task를 만들었습니다. 이어서 Schedule 정보를 입력해 주세요.'
                  : 'Task created. Continue with the schedule details.',
            );
            return;
          }
        }
      } else {
        final selectedTask = ref
            .read(tasksProvider)
            .value
            ?.where((task) => task.id == _selectedTaskId)
            .firstOrNull;
        if (selectedTask == null) {
          throw StateError(
            _isKo
                ? '선택한 Task를 찾을 수 없습니다. 목록을 새로고침해 주세요.'
                : 'The selected task is no longer available. Refresh and retry.',
          );
        }
        final start = _isAllDay
            ? _date
            : DateTime(
                _date.year,
                _date.month,
                _date.day,
                _start.hour,
                _start.minute,
              );
        final end = _isAllDay
            ? _date.add(const Duration(days: 1))
            : DateTime(
                _date.year,
                _date.month,
                _date.day,
                _end.hour,
                _end.minute,
              );
        final description = _detailed
            ? _descriptionController.text.trim()
            : widget.schedule?.description;
        final location = _detailed
            ? _locationController.text.trim()
            : widget.schedule?.location;
        final updatedDescription = _detailed ? description ?? '' : description;
        final updatedLocation = _detailed ? location ?? '' : location;
        if (widget.schedule?.id case final eventId?) {
          await ref.read(calendarEventsProvider.notifier).updateEvent(
                eventId: eventId,
                summary: _titleController.text.trim(),
                relatedTask: ScheduleTaskLink(
                  taskId: selectedTask.id,
                  taskName: selectedTask.title,
                ),
                start: start,
                end: end,
                timezone: widget.timezone,
                isAllDay: _isAllDay,
                isBusy: _isBusy,
                visibility: _visibility,
                colorId: _category.googleColorId,
                recurrence: _recurrence == 'none'
                    ? const []
                    : ['RRULE:FREQ=$_recurrence'],
                description: updatedDescription,
                location: updatedLocation,
              );
        } else {
          await ref.read(calendarEventsProvider.notifier).createEvent(
                summary: _titleController.text.trim(),
                relatedTask: ScheduleTaskLink(
                  taskId: selectedTask.id,
                  taskName: selectedTask.title,
                ),
                start: start,
                end: end,
                timezone: widget.timezone,
                colorId: _category.googleColorId,
                description: description?.isEmpty == true ? null : description,
                location: location?.isEmpty == true ? null : location,
                recurrence: _recurrence == 'none' ? null : _recurrence,
                transparency: _isBusy ? 'opaque' : 'transparent',
                visibility: _visibility,
                isAllDay: _isAllDay,
              );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        _showMessage(
          _isKo ? '저장하지 못했습니다: $error' : 'Could not save: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteSchedule(String eventId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isKo ? 'Schedule 삭제' : 'Delete schedule'),
        content: Text(_isKo ? '이 Schedule을 삭제할까요?' : 'Delete this schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_isKo ? '취소' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_isKo ? '삭제' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await ref.read(calendarEventsProvider.notifier).deleteEvent(eventId);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        _showMessage(
          _isKo ? '삭제하지 못했습니다: $error' : 'Could not delete: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }
}

class _NoTasksHint extends StatelessWidget {
  const _NoTasksHint({required this.isKo, required this.onCreateTask});

  final bool isKo;
  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isKo
                    ? 'Schedule을 만들려면 먼저 연관 Task가 필요합니다.'
                    : 'Create a related task before adding a schedule.',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCreateTask,
                  icon: const Icon(Icons.add_task),
                  label: Text(isKo ? 'Task 먼저 만들기' : 'Create a task'),
                ),
              ),
            ],
          ),
        ),
      );
}
