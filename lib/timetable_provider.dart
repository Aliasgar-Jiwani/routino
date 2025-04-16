import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import 'timetable_entry.dart';

class TimetableProvider extends ChangeNotifier {
  final Box<TimetableEntry> _timetableBox = Hive.box<TimetableEntry>('timetable');
  List<TimetableEntry> _entries = [];
  bool _notificationsEnabled = true;
  String _selectedDay = '';
  FlutterLocalNotificationsPlugin? _notificationsPlugin;

  bool get notificationsEnabled => _notificationsEnabled;
  String get selectedDay => _selectedDay.isEmpty ? _getCurrentDay() : _selectedDay;

  TimetableProvider() {
    loadTimetable();
    _selectedDay = _getCurrentDay(); // Initialize with current day
  }

  void loadTimetable() {
    _entries = _timetableBox.values.toList();
    notifyListeners();
  }

  void addEntry(TimetableEntry entry) {
    _timetableBox.add(entry);
    loadTimetable();
    if (_notificationsPlugin != null) {
      scheduleWeeklyNotifications(_notificationsPlugin!);
    }
  }

  void updateEntry(TimetableEntry oldEntry, TimetableEntry newEntry) {
    final key = oldEntry.key; // Get the entry's unique key
    if (key != null && _timetableBox.containsKey(key)) {
      _timetableBox.put(key, newEntry); // Update using the key
      loadTimetable(); // Refresh the UI
      if (_notificationsPlugin != null) {
        scheduleWeeklyNotifications(_notificationsPlugin!);
      }
    }
  }

  void deleteEntry(TimetableEntry entry) {
    final index = _timetableBox.values.toList().indexOf(entry);
    if (index >= 0) {
      _timetableBox.deleteAt(index);
      loadTimetable();
      if (_notificationsPlugin != null) {
        scheduleWeeklyNotifications(_notificationsPlugin!);
      }
    }
  }

  void resetTimetable() {
    _timetableBox.clear();
    loadTimetable();
    if (_notificationsPlugin != null) {
      _notificationsPlugin!.cancelAll();
    }
  }

  void setNotificationsEnabled(bool enabled, BuildContext context) {
    _notificationsEnabled = enabled;
    notifyListeners();
    if (enabled) {
      _checkNotificationPermissions(context);
      if (_notificationsPlugin != null) {
        scheduleWeeklyNotifications(_notificationsPlugin!);
      }
    } else if (_notificationsPlugin != null) {
      _notificationsPlugin!.cancelAll();
    }
  }

  void setSelectedDay(String day) {
    _selectedDay = day;
    notifyListeners();
  }

  String _getCurrentDay() {
    final now = DateTime.now();
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[now.weekday - 1];
  }

  List<TimetableEntry> getEntriesForDay(String day) {
    return _entries.where((entry) => entry.day == day).toList()
      ..sort((a, b) {
        final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
        return aMinutes.compareTo(bMinutes);
      });
  }

  List<TimetableEntry> getTodayEntries() {
    return getEntriesForDay(selectedDay);
  }

  List<String> getAllDays() {
    return [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
  }

  TimetableEntry? getCurrentTask() {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    // Only check for current tasks if the selected day is the current day
    if (selectedDay != _getCurrentDay()) return null;

    final todayEntries = getTodayEntries();
    if (todayEntries.isEmpty) return null;

    try {
      return todayEntries.firstWhere(
        (entry) {
          final startMinutes = entry.startTime.hour * 60 + entry.startTime.minute;
          final endMinutes = entry.endTime.hour * 60 + entry.endTime.minute;
          return nowMinutes >= startMinutes && nowMinutes < endMinutes;
        },
      );
    } catch (e) {
      return null;
    }
  }

  void updateCurrentTask() {
    notifyListeners();
  }

  bool isCurrentTask(TimetableEntry entry) {
    final currentTask = getCurrentTask();
    if (currentTask == null) return false;
    return currentTask.day == entry.day && currentTask.taskName == entry.taskName && currentTask.startTime.hour == entry.startTime.hour && currentTask.startTime.minute == entry.startTime.minute;
  }

  TimetableEntry? getNextTask() {
    // Only check for next tasks if the selected day is the current day
    if (selectedDay != _getCurrentDay()) return null;

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final todayEntries = getTodayEntries();
    for (var entry in todayEntries) {
      final startMinutes = entry.startTime.hour * 60 + entry.startTime.minute;
      if (startMinutes > nowMinutes) {
        return entry;
      }
    }
    return null;
  }

  double getCurrentProgressInDay() {
    // Only show progress if the selected day is the current day
    if (selectedDay != _getCurrentDay()) return 0.0;

    final todayEntries = getTodayEntries();
    if (todayEntries.isEmpty) return 0.0;
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    int earliestStart = 24 * 60;
    int latestEnd = 0;
    for (var entry in todayEntries) {
      final startMinutes = entry.startTime.hour * 60 + entry.startTime.minute;
      final endMinutes = entry.endTime.hour * 60 + entry.endTime.minute;
      if (startMinutes < earliestStart) earliestStart = startMinutes;
      if (endMinutes > latestEnd) latestEnd = endMinutes;
    }
    if (nowMinutes < earliestStart) return 0.0;
    if (nowMinutes > latestEnd) return 1.0;
    return (nowMinutes - earliestStart) / (latestEnd - earliestStart);
  }

  Future<void> _checkNotificationPermissions(BuildContext context) async {
    if (Platform.isAndroid) {
      // Check notification permission for Android 13+ (API 33+)
      final notificationStatus = await Permission.notification.status;
      print('Notification permission status: $notificationStatus');

      if (notificationStatus.isDenied) {
        final result = await Permission.notification.request();
        print('Notification permission request result: $result');
      }

      // Check for exact alarm permission
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      print('Exact alarm permission status: $alarmStatus');

      if (alarmStatus.isDenied || alarmStatus.isPermanentlyDenied) {
        final result = await Permission.scheduleExactAlarm.request();
        print('Exact alarm permission request result: $result');

        if (!result.isGranted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Permission Required'),
                content: const Text(
                  'Please enable "Schedule Exact Alarms" in device settings to receive notifications. Without this permission, the app cannot schedule notifications for your tasks.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );
          });
        }
      }
    }
  }

  Future<void> sendTestNotification() async {
    if (_notificationsPlugin == null) return;
    print('Sending test notification');

    try {
      final androidDetails = AndroidNotificationDetails(
        'timetable_channel',
        'Timetable Notifications',
        channelDescription: 'Test notification',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      final platformDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin!.show(
        999, // Unique ID for test
        'Test Notification',
        'This is a test notification from your timetable app',
        platformDetails,
      );

      print('Test notification sent successfully');
    } catch (e) {
      print('Failed to send test notification: $e');
    }
  }

  // This function is kept for backward compatibility but now just calls scheduleWeeklyNotifications
  void scheduleNotifications(FlutterLocalNotificationsPlugin notificationsPlugin) async {
    scheduleWeeklyNotifications(notificationsPlugin);
  }

  void scheduleWeeklyNotifications(FlutterLocalNotificationsPlugin notificationsPlugin) async {
    _notificationsPlugin = notificationsPlugin;
    if (!_notificationsEnabled) {
      print('Notifications are disabled. Not scheduling.');
      return;
    }

    print('Scheduling weekly notifications - Start');

    try {
      // Cancel any existing notifications first
      await notificationsPlugin.cancelAll();
      print('Cancelled all existing notifications');

      final now = DateTime.now();
      final days = getAllDays();
      int scheduledCount = 0;

      // Loop through all days of the week
      for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
        final dayName = days[dayIndex];

        // Get entries for this day
        final entries = getEntriesForDay(dayName);
        print('Found ${entries.length} entries for $dayName');

        for (var entry in entries) {
          // Calculate the next occurrence of this weekday (1-based, Monday=1, Sunday=7)
          int targetWeekday = dayIndex + 1;
          int daysUntilNextOccurrence = (targetWeekday - now.weekday) % 7;
          if (daysUntilNextOccurrence == 0 && (now.hour > entry.startTime.hour || (now.hour == entry.startTime.hour && now.minute >= entry.startTime.minute))) {
            daysUntilNextOccurrence = 7; // Next week if today's occurrence has passed
          }

          // Next occurrence date
          final nextOccurrence = now.add(Duration(days: daysUntilNextOccurrence));

          // Create the task start time for this day
          final taskStartTime = DateTime(
            nextOccurrence.year,
            nextOccurrence.month,
            nextOccurrence.day,
            entry.startTime.hour,
            entry.startTime.minute,
          );

          // 1. Schedule recurring notification 5 minutes before task starts
          final preNotificationTime = taskStartTime.subtract(const Duration(minutes: 5));

          try {
            final androidDetails = AndroidNotificationDetails(
              'timetable_channel',
              'Timetable Notifications',
              channelDescription: 'Notifications for upcoming tasks',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              vibrationPattern: Int64List.fromList([
                0,
                1000,
                500,
                1000
              ]),
              category: AndroidNotificationCategory.reminder,
              visibility: NotificationVisibility.public,
            );

            final platformDetails = NotificationDetails(android: androidDetails);

            // Create a unique ID for the pre-notification
            final preNotificationId = '${entry.day}${entry.taskName}${entry.startTime.hour}${entry.startTime.minute}_pre'.hashCode;

            // Convert to timezone DateTime
            final tzPreDateTime = tz.TZDateTime.from(preNotificationTime, tz.local);
            print('Scheduling weekly pre-notification ID $preNotificationId for ${entry.taskName} on ${dayName}');

            // Schedule a repeating weekly notification
            await notificationsPlugin.zonedSchedule(
              preNotificationId,
              'Time for ${entry.taskName} soon',
              'Starting in 5 minutes',
              tzPreDateTime,
              platformDetails,
              androidAllowWhileIdle: true,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // This makes it weekly recurring
            );

            print('Successfully scheduled weekly pre-notification for ${entry.taskName} on ${dayName}');
            scheduledCount++;
          } catch (e) {
            print('Failed to schedule pre-notification for ${entry.taskName} on ${dayName}: $e');
          }

          // 2. Schedule notification at task start time (weekly recurring)
          try {
            final androidDetails = AndroidNotificationDetails(
              'timetable_channel',
              'Timetable Notifications',
              channelDescription: 'Notifications for task start',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              vibrationPattern: Int64List.fromList([
                0,
                1000,
                500,
                1000
              ]),
              category: AndroidNotificationCategory.reminder,
              visibility: NotificationVisibility.public,
            );

            final platformDetails = NotificationDetails(android: androidDetails);

            // Create a unique ID for the start notification
            final startNotificationId = '${entry.day}${entry.taskName}${entry.startTime.hour}${entry.startTime.minute}_start'.hashCode;

            // Convert to timezone DateTime
            final tzStartDateTime = tz.TZDateTime.from(taskStartTime, tz.local);
            print('Scheduling weekly start notification ID $startNotificationId for ${entry.taskName} on ${dayName}');

            // Schedule a repeating weekly notification
            await notificationsPlugin.zonedSchedule(
              startNotificationId,
              'Time for ${entry.taskName}',
              'Task is starting now',
              tzStartDateTime,
              platformDetails,
              androidAllowWhileIdle: true,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // This makes it weekly recurring
            );

            print('Successfully scheduled weekly start notification for ${entry.taskName} on ${dayName}');
            scheduledCount++;
          } catch (e) {
            print('Failed to schedule start notification for ${entry.taskName} on ${dayName}: $e');
          }
        }
      }

      print('Scheduled $scheduledCount recurring weekly notifications');
    } catch (e) {
      print('Error in scheduleWeeklyNotifications: $e');
    }
  }

  // Debug helper function
  Future<void> checkAndPrintNotificationStatus(BuildContext context) async {
    if (Platform.isAndroid) {
      final notificationStatus = await Permission.notification.status;
      final alarmStatus = await Permission.scheduleExactAlarm.status;

      final message = 'Notification permission: $notificationStatus\n' + 'Exact alarm permission: $alarmStatus\n' + 'Notifications enabled in app: $_notificationsEnabled';

      print(message);

      // Show a snackbar with the diagnostic info
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
