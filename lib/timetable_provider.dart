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
  BuildContext Function()? _contextProvider;

  bool get notificationsEnabled => _notificationsEnabled;
  String get selectedDay => _selectedDay.isEmpty ? _getCurrentDay() : _selectedDay;

  TimetableProvider() {
    loadTimetable();
    _selectedDay = _getCurrentDay(); // Initialize with current day
  }

  void setContextProvider(BuildContext Function() provider) {
    _contextProvider = provider;
  }

  BuildContext? _getContext() {
    try {
      return _contextProvider?.call();
    } catch (e) {
      debugPrint('Error getting context: $e');
      return null;
    }
  }

  void loadTimetable() {
    try {
      _entries = _timetableBox.values.toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading timetable: $e');
      _entries = [];
    }
  }

  void addEntry(TimetableEntry entry) {
    try {
      _timetableBox.add(entry);
      loadTimetable();
      if (_notificationsPlugin != null && _notificationsEnabled) {
        _scheduleWeeklyNotificationsInternal(_notificationsPlugin!);
      }
    } catch (e) {
      debugPrint('Error adding entry: $e');
    }
  }

  void updateEntry(TimetableEntry oldEntry, TimetableEntry newEntry) {
    try {
      final key = oldEntry.key; // Get the entry's unique key
      if (key != null && _timetableBox.containsKey(key)) {
        _timetableBox.put(key, newEntry); // Update using the key
        loadTimetable(); // Refresh the UI
        if (_notificationsPlugin != null && _notificationsEnabled) {
          _scheduleWeeklyNotificationsInternal(_notificationsPlugin!);
        }
      }
    } catch (e) {
      debugPrint('Error updating entry: $e');
    }
  }

  void deleteEntry(TimetableEntry entry) {
    try {
      final index = _timetableBox.values.toList().indexOf(entry);
      if (index >= 0) {
        _timetableBox.deleteAt(index);
        loadTimetable();
        if (_notificationsPlugin != null && _notificationsEnabled) {
          _scheduleWeeklyNotificationsInternal(_notificationsPlugin!);
        }
      }
    } catch (e) {
      debugPrint('Error deleting entry: $e');
    }
  }

  void resetTimetable() {
    try {
      _timetableBox.clear();
      loadTimetable();
      if (_notificationsPlugin != null) {
        _notificationsPlugin!.cancelAll();
      }
    } catch (e) {
      debugPrint('Error resetting timetable: $e');
    }
  }

  Future<void> setNotificationsEnabled(bool enabled, BuildContext context) async {
    try {
      _notificationsEnabled = enabled;
      notifyListeners();

      if (enabled) {
        final permissionsGranted = await _checkNotificationPermissions(context);
        if (permissionsGranted && _notificationsPlugin != null) {
          _scheduleWeeklyNotificationsInternal(_notificationsPlugin!);
        }
      } else if (_notificationsPlugin != null) {
        _notificationsPlugin!.cancelAll();
      }
    } catch (e) {
      debugPrint('Error setting notifications: $e');
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
    try {
      return _entries.where((entry) => entry.day == day).toList()
        ..sort((a, b) {
          final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
          final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
          return aMinutes.compareTo(bMinutes);
        });
    } catch (e) {
      debugPrint('Error getting entries for day: $e');
      return [];
    }
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
    try {
      final now = TimeOfDay.now();
      final nowMinutes = now.hour * 60 + now.minute;

      // Only check for current tasks if the selected day is the current day
      if (selectedDay != _getCurrentDay()) return null;

      final todayEntries = getTodayEntries();
      if (todayEntries.isEmpty) return null;

      for (var entry in todayEntries) {
        final startMinutes = entry.startTime.hour * 60 + entry.startTime.minute;
        final endMinutes = entry.endTime.hour * 60 + entry.endTime.minute;
        if (nowMinutes >= startMinutes && nowMinutes < endMinutes) {
          return entry;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting current task: $e');
      return null;
    }
  }

  void updateCurrentTask() {
    notifyListeners();
  }

  bool isCurrentTask(TimetableEntry entry) {
    try {
      final currentTask = getCurrentTask();
      if (currentTask == null) return false;
      return currentTask.day == entry.day && currentTask.taskName == entry.taskName && currentTask.startTime.hour == entry.startTime.hour && currentTask.startTime.minute == entry.startTime.minute;
    } catch (e) {
      debugPrint('Error checking if is current task: $e');
      return false;
    }
  }

  TimetableEntry? getNextTask() {
    try {
      // Only check for next tasks if the selected day is the current day
      if (selectedDay != _getCurrentDay()) return null;

      final now = TimeOfDay.now();
      final nowMinutes = now.hour * 60 + now.minute;
      final todayEntries = getTodayEntries();

      // Sort entries by start time
      todayEntries.sort((a, b) {
        final aStartMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bStartMinutes = b.startTime.hour * 60 + b.startTime.minute;
        return aStartMinutes.compareTo(bStartMinutes);
      });

      for (var entry in todayEntries) {
        final startMinutes = entry.startTime.hour * 60 + entry.startTime.minute;
        if (startMinutes > nowMinutes) {
          return entry;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting next task: $e');
      return null;
    }
  }

  double getCurrentProgressInDay() {
    try {
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
      if (latestEnd - earliestStart <= 0) return 0.0; // Prevent division by zero

      return (nowMinutes - earliestStart) / (latestEnd - earliestStart);
    } catch (e) {
      debugPrint('Error getting current progress: $e');
      return 0.0;
    }
  }

  Future<bool> _checkNotificationPermissions(BuildContext context) async {
    try {
      bool permissionsGranted = false;

      if (Platform.isAndroid) {
        // First check notification permission
        final notificationStatus = await Permission.notification.status;

        if (notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
          if (notificationStatus.isPermanentlyDenied) {
            // Show dialog to direct to settings since we can't request directly
            _showPermissionSettingsDialog(context, 'notification');
            return false;
          } else {
            // Request permission
            final result = await Permission.notification.request();
            if (!result.isGranted) {
              return false;
            }
          }
        }

        // Then check exact alarm permission
        final alarmStatus = await Permission.scheduleExactAlarm.status;
        if (alarmStatus.isDenied || alarmStatus.isPermanentlyDenied) {
          if (alarmStatus.isPermanentlyDenied) {
            _showPermissionSettingsDialog(context, 'exact alarm');
            return false;
          } else {
            final result = await Permission.scheduleExactAlarm.request();
            if (!result.isGranted) {
              _showPermissionSettingsDialog(context, 'exact alarm');
              return false;
            }
          }
        }

        permissionsGranted = notificationStatus.isGranted && alarmStatus.isGranted;
      } else if (Platform.isIOS) {
        // iOS permissions are handled during plugin initialization
        permissionsGranted = true;
      }

      return permissionsGranted;
    } catch (e) {
      debugPrint('Error checking notification permissions: $e');
      return false;
    }
  }

  void _showPermissionSettingsDialog(BuildContext context, String permissionType) {
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('$permissionType Permission Required'),
              content: Text(
                'Please enable $permissionType permissions in device settings to receive notifications.',
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
        }
      });
    } catch (e) {
      debugPrint('Error showing permission dialog: $e');
    }
  }

  Future<void> sendTestNotification() async {
    try {
      if (_notificationsPlugin == null) return;
      debugPrint('Sending test notification');

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

      debugPrint('Test notification sent successfully');
    } catch (e) {
      debugPrint('Failed to send test notification: $e');
    }
  }

  // This function is kept for backward compatibility and delegates to internal function
  void scheduleNotifications(FlutterLocalNotificationsPlugin notificationsPlugin) async {
    try {
      _notificationsPlugin = notificationsPlugin;
      if (!_notificationsEnabled) {
        debugPrint('Notifications are disabled. Not scheduling.');
        return;
      }

      final context = _getContext();
      if (context != null) {
        final permissionsGranted = await _checkNotificationPermissions(context);
        if (!permissionsGranted) {
          debugPrint('Notification permissions not granted');
          return;
        }
      }

      _scheduleWeeklyNotificationsInternal(notificationsPlugin);
    } catch (e) {
      debugPrint('Error scheduling notifications: $e');
    }
  }

  // Changed to internal function to avoid recursion and handle permissions separately
  void _scheduleWeeklyNotificationsInternal(FlutterLocalNotificationsPlugin notificationsPlugin) async {
    try {
      debugPrint('Scheduling weekly notifications - Start');

      // Cancel any existing notifications first
      await notificationsPlugin.cancelAll();
      debugPrint('Cancelled all existing notifications');

      final now = DateTime.now();
      final days = getAllDays();
      int scheduledCount = 0;

      // Loop through all days of the week
      for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
        final dayName = days[dayIndex];

        // Get entries for this day
        final entries = getEntriesForDay(dayName);
        debugPrint('Found ${entries.length} entries for $dayName');

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

          await _scheduleIndividualNotification(notificationsPlugin, _generateNotificationId(entry.day, entry.taskName, entry.startTime.hour, entry.startTime.minute, 'pre'), 'Time for ${entry.taskName} soon', 'Starting in 5 minutes', preNotificationTime, dayName, entry.taskName, 'pre', scheduledCount);
          scheduledCount++;

          // 2. Schedule notification at task start time (weekly recurring)
          await _scheduleIndividualNotification(notificationsPlugin, _generateNotificationId(entry.day, entry.taskName, entry.startTime.hour, entry.startTime.minute, 'start'), 'Time for ${entry.taskName}', 'Task is starting now', taskStartTime, dayName, entry.taskName, 'start', scheduledCount);
          scheduledCount++;
        }
      }

      debugPrint('Scheduled $scheduledCount recurring weekly notifications');
    } catch (e) {
      debugPrint('Error in scheduleWeeklyNotifications: $e');
    }
  }

  Future<void> _scheduleIndividualNotification(FlutterLocalNotificationsPlugin notificationsPlugin, int notificationId, String title, String body, DateTime scheduledTime, String dayName, String taskName, String notificationType, int count) async {
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

      final iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      // Safe conversion to timezone DateTime
      tz.TZDateTime tzScheduledTime;
      try {
        tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
      } catch (e) {
        // Fallback if timezone conversion fails
        debugPrint('Error converting to timezone: $e');
        tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.UTC);
      }

      debugPrint('Scheduling notification ID $notificationId for $taskName on $dayName ($notificationType)');

      // Schedule a repeating weekly notification
      await notificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        tzScheduledTime,
        platformDetails,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // This makes it weekly recurring
      );

      debugPrint('Successfully scheduled notification for $taskName on $dayName ($notificationType)');
    } catch (e) {
      debugPrint('Failed to schedule notification for $taskName on $dayName ($notificationType): $e');
    }
  }

  // Generate consistent notification IDs
  int _generateNotificationId(String day, String taskName, int hour, int minute, String type) {
    // Create a deterministic ID based on day, task, time and type
    // Keep IDs within 32-bit integer range and positive
    String idString = '$day-$taskName-$hour$minute-$type';
    int code = 0;
    for (int i = 0; i < idString.length; i++) {
      code = ((code * 31) % 2147483647) + idString.codeUnitAt(i);
    }
    return code.abs() % 2147483647; // Ensure positive and within range
  }

  // Debug helper function for checking notification status
  Future<String> checkAndPrintNotificationStatus(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        final notificationStatus = await Permission.notification.status;
        final alarmStatus = await Permission.scheduleExactAlarm.status;

        final message = 'Notification permission: $notificationStatus\n' + 'Exact alarm permission: $alarmStatus\n' + 'Notifications enabled in app: $_notificationsEnabled';

        debugPrint(message);
        return message;
      }
      return 'Device is not Android';
    } catch (e) {
      debugPrint('Error checking notification status: $e');
      return 'Error checking notification status: $e';
    }
  }

  void scheduleWeeklyNotifications(FlutterLocalNotificationsPlugin notificationsPlugin) async {
    try {
      _notificationsPlugin = notificationsPlugin;
      if (!_notificationsEnabled) {
        debugPrint('Notifications are disabled. Not scheduling.');
        return;
      }

      final context = _getContext();
      if (context != null) {
        final permissionsGranted = await _checkNotificationPermissions(context);
        if (!permissionsGranted) {
          debugPrint('Notification permissions not granted');
          return;
        }
      }

      _scheduleWeeklyNotificationsInternal(notificationsPlugin);
    } catch (e) {
      debugPrint('Error in scheduleWeeklyNotifications: $e');
    }
  }
}
