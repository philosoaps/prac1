import 'package:googleapis/calendar/v3.dart' as goog_cal;

class ScheduleTaskLink {
  const ScheduleTaskLink({
    required this.taskId,
    required this.taskName,
  });

  static const taskIdKey = 'relatedTaskId';
  static const taskNameKey = 'relatedTaskName';

  final String taskId;
  final String taskName;

  Map<String, String> toPrivateProperties() => {
        taskIdKey: taskId,
        taskNameKey: taskName,
      };

  factory ScheduleTaskLink.fromEvent(goog_cal.Event event) {
    final properties = event.extendedProperties?.private;
    return ScheduleTaskLink(
      taskId: properties?[taskIdKey] ?? '',
      taskName: properties?[taskNameKey] ?? '',
    );
  }
}
