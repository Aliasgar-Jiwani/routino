import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'timetable_entry.dart';
import 'timetable_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNotifications();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TimetableProvider>(context, listen: false);
      provider.loadTimetable();
      provider.scheduleNotifications(_notificationsPlugin);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Provider.of<TimetableProvider>(context, listen: false).loadTimetable();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      Provider.of<TimetableProvider>(context, listen: false).updateCurrentTask();
    });
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _notificationsPlugin.initialize(initializationSettings);

    // Create Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'timetable_channel',
      'Timetable Notifications',
      description: 'Notifications for upcoming tasks',
      importance: Importance.high,
      playSound: true,
    );
    await _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

    // Request permissions for both platforms
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestPermission(); // Added Android permission request
    }
    await _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Routino'),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.home), text: 'Now'),
                  Tab(icon: Icon(Icons.calendar_today), text: 'Today'),
                  Tab(icon: Icon(Icons.settings), text: 'Settings'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildNowTab(provider),
                _buildTodayTab(provider),
                _buildSettingsTab(provider),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showAddEntryDialog(context),
              child: const Icon(Icons.add),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNowTab(TimetableProvider provider) {
    final currentTask = provider.getCurrentTask();
    final nextTask = provider.getNextTask();

    // Wrap the entire content in a SingleChildScrollView to prevent overflow
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "What's happening now",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            currentTask != null
                ? _buildTaskCard(currentTask, isCurrentTask: true)
                : const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No task scheduled for now',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
            const SizedBox(height: 32),
            const Text(
              "Coming up next",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            nextTask != null
                ? _buildTaskCard(nextTask)
                : const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No upcoming tasks today',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
            if (currentTask != null && provider.getTodayEntries().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: LinearProgressIndicator(
                  value: provider.getCurrentProgressInDay(),
                  minHeight: 10,
                  backgroundColor: Colors.grey[300],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(TimetableEntry task, {bool isCurrentTask = false}) {
    return Card(
      elevation: 3,
      color: isCurrentTask ? Colors.blue.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForTask(task.taskName),
                  size: 24,
                  color: isCurrentTask ? Colors.blue : Colors.grey[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.taskName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isCurrentTask ? Colors.blue[800] : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatTimeOfDay(task.startTime)} - ${_formatTimeOfDay(task.endTime)}',
              style: TextStyle(
                fontSize: 16,
                color: isCurrentTask ? Colors.blue[700] : Colors.black54,
              ),
            ),
            if (task.notes != null && task.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  task.notes!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTab(TimetableProvider provider) {
    final todayEntries = provider.getTodayEntries();
    if (todayEntries.isEmpty) {
      return const Center(child: Text('No tasks scheduled for today'));
    }
    return ListView.builder(
      itemCount: todayEntries.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final entry = todayEntries[index];
        final isCurrentTask = provider.isCurrentTask(entry);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Card(
            elevation: 2,
            color: isCurrentTask ? Colors.blue.shade50 : null,
            child: ListTile(
              leading: Icon(
                _getIconForTask(entry.taskName),
                color: isCurrentTask ? Colors.blue : null,
              ),
              title: Text(
                entry.taskName,
                style: TextStyle(
                  fontWeight: isCurrentTask ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_formatTimeOfDay(entry.startTime)} - ${_formatTimeOfDay(entry.endTime)}'),
                  if (entry.notes != null && entry.notes!.isNotEmpty)
                    Text(
                      entry.notes!,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditEntryDialog(context, entry),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _showDeleteConfirmationDialog(context, entry),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab(TimetableProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SwitchListTile(
            title: const Text('Enable notifications'),
            subtitle: const Text('Get notified before tasks begin'),
            value: provider.notificationsEnabled,
            onChanged: (bool value) {
              provider.setNotificationsEnabled(value, context); // Pass context here
              if (value) {
                provider.scheduleNotifications(_notificationsPlugin);
              }
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Reset Timetable'),
            subtitle: const Text('Delete all timetable entries'),
            trailing: const Icon(Icons.delete_forever),
            onTap: () => _showResetConfirmationDialog(context),
          ),
          const Divider(),
          const SizedBox(height: 20),
          const Text(
            'Day View Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ListTile(
            title: const Text('Choose Day to View'),
            subtitle: Text('Currently showing: ${provider.selectedDay}'),
            trailing: const Icon(Icons.calendar_month),
            onTap: () => _showDaySelectionDialog(context, provider),
          ),
        ],
      ),
    );
  }

  void _showAddEntryDialog(BuildContext context) {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    String day = 'Monday';
    String taskName = '';
    TimeOfDay startTime = TimeOfDay.now();
    TimeOfDay endTime = TimeOfDay(
      hour: TimeOfDay.now().hour + 1,
      minute: TimeOfDay.now().minute,
    );
    String? notes;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Timetable Entry'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: day,
                    decoration: const InputDecoration(labelText: 'Day of the Week'),
                    items: const [
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                      'Sunday',
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      day = newValue!;
                    },
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Task Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a task name';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      taskName = value;
                    },
                  ),
                  ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(_formatTimeOfDay(startTime)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: startTime,
                      );
                      if (pickedTime != null) {
                        startTime = pickedTime;
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('End Time'),
                    subtitle: Text(_formatTimeOfDay(endTime)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: endTime,
                      );
                      if (pickedTime != null) {
                        endTime = pickedTime;
                      }
                    },
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                    maxLines: 2,
                    onChanged: (value) {
                      notes = value;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newEntry = TimetableEntry(
                    day: day,
                    taskName: taskName,
                    startTime: startTime,
                    endTime: endTime,
                    notes: notes,
                  );
                  provider.addEntry(newEntry);
                  provider.scheduleNotifications(_notificationsPlugin);
                  Navigator.pop(context);

                  // Show success notification
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Task "$taskName" added successfully for $day'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditEntryDialog(BuildContext context, TimetableEntry entry) {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    String day = entry.day;
    String taskName = entry.taskName;
    TimeOfDay startTime = entry.startTime;
    TimeOfDay endTime = entry.endTime;
    String? notes = entry.notes;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Timetable Entry'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: day,
                        decoration: const InputDecoration(labelText: 'Day of the Week'),
                        items: const [
                          'Monday',
                          'Tuesday',
                          'Wednesday',
                          'Thursday',
                          'Friday',
                          'Saturday',
                          'Sunday',
                        ].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() => day = newValue!);
                        },
                      ),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Task Name'),
                        initialValue: taskName,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a task name';
                          }
                          return null;
                        },
                        onChanged: (value) => setState(() => taskName = value),
                      ),
                      ListTile(
                        title: const Text('Start Time'),
                        subtitle: Text(_formatTimeOfDay(startTime)),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: startTime,
                          );
                          if (pickedTime != null) {
                            setState(() => startTime = pickedTime);
                          }
                        },
                      ),
                      ListTile(
                        title: const Text('End Time'),
                        subtitle: Text(_formatTimeOfDay(endTime)),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: endTime,
                          );
                          if (pickedTime != null) {
                            setState(() => endTime = pickedTime);
                          }
                        },
                      ),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                        initialValue: notes,
                        maxLines: 2,
                        onChanged: (value) => setState(() => notes = value),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final updatedEntry = TimetableEntry(
                    day: day,
                    taskName: taskName,
                    startTime: startTime,
                    endTime: endTime,
                    notes: notes,
                  );
                  provider.updateEntry(entry, updatedEntry);
                  provider.scheduleNotifications(_notificationsPlugin);
                  Navigator.pop(context);

                  // Show success notification for edit
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Task "$taskName" updated successfully for $day'),
                      backgroundColor: Colors.blue,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, TimetableEntry entry) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Entry'),
          content: Text('Are you sure you want to delete "${entry.taskName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final taskName = entry.taskName;
                final day = entry.day;
                Provider.of<TimetableProvider>(context, listen: false).deleteEntry(entry);
                Navigator.pop(context);

                // Show success notification for delete
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Task "$taskName" deleted from $day'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Timetable'),
          content: const Text(
            'Are you sure you want to delete all timetable entries? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Provider.of<TimetableProvider>(context, listen: false).resetTimetable();
                Navigator.pop(context);

                // Show notification for reset
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Timetable has been reset'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  void _showDaySelectionDialog(BuildContext context, TimetableProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday',
            ].map((day) {
              return ListTile(
                title: Text(day),
                onTap: () {
                  provider.setSelectedDay(day);
                  Navigator.pop(context);
                },
                selected: provider.selectedDay == day,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm').format(dt);
  }

  IconData _getIconForTask(String taskName) {
    final taskLower = taskName.toLowerCase();
    if (taskLower.contains('study') || taskLower.contains('class') || taskLower.contains('lecture')) {
      return Icons.school;
    } else if (taskLower.contains('break') || taskLower.contains('lunch') || taskLower.contains('rest')) {
      return Icons.free_breakfast;
    } else if (taskLower.contains('exercise') || taskLower.contains('gym') || taskLower.contains('workout')) {
      return Icons.fitness_center;
    } else if (taskLower.contains('meeting') || taskLower.contains('appointment')) {
      return Icons.people;
    } else if (taskLower.contains('work') || taskLower.contains('project')) {
      return Icons.work;
    } else {
      return Icons.event_note;
    }
  }
}
