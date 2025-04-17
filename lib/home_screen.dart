import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'timetable_entry.dart';
import 'timetable_provider.dart';

// App theme colors
class AppColors {
  static const primary = Color(0xFF6200EE);
  static const primaryVariant = Color(0xFF3700B3);
  static const secondary = Color(0xFF03DAC6);
  static const secondaryVariant = Color(0xFF018786);
  static const background = Color(0xFFF5F5F5);
  static const surface = Colors.white;
  static const error = Color(0xFFB00020);
  static const onPrimary = Colors.white;
  static const onSecondary = Colors.black;
  static const onBackground = Colors.black;
  static const onSurface = Colors.black;
  static const onError = Colors.white;

  // Task category colors
  static const study = Color(0xFF6200EE);
  static const work = Color(0xFF0277BD);
  static const exercise = Color(0xFF388E3C);
  static const leisure = Color(0xFFFF8F00);
  static const meeting = Color(0xFFD32F2F);
  static const other = Color(0xFF5D4037);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _tabController.dispose();
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
      await androidPlugin?.requestPermission();
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
        return Theme(
          data: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              primaryContainer: AppColors.primaryVariant,
              secondary: AppColors.secondary,
              secondaryContainer: AppColors.secondaryVariant,
              surface: AppColors.surface,
              background: AppColors.background,
              error: AppColors.error,
            ),
            textTheme: GoogleFonts.poppinsTextTheme(
              Theme.of(context).textTheme,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 0,
            ),
            cardTheme: CardTheme(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
            ),
            tabBarTheme: TabBarTheme(
              labelColor: AppColors.onPrimary,
              unselectedLabelColor: AppColors.onPrimary.withOpacity(0.7),
              indicatorColor: AppColors.secondary,
              indicatorSize: TabBarIndicatorSize.label,
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.onSecondary,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: Row(
                children: [
                  // Icon(Icons.schedule, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Routino',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              bottom: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    icon: Icon(Icons.access_time_rounded),
                    text: 'Now',
                  ),
                  Tab(
                    icon: Icon(Icons.calendar_today_rounded),
                    text: 'Today',
                  ),
                  Tab(
                    icon: Icon(Icons.settings_rounded),
                    text: 'Settings',
                  ),
                ],
                indicatorWeight: 3,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildNowTab(provider),
                _buildTodayTab(provider),
                _buildSettingsTab(provider),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _showAddEntryDialog(context),
              icon: Icon(Icons.add_rounded),
              label: Text('Add Task'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNowTab(TimetableProvider provider) {
    final currentTask = provider.getCurrentTask();
    final nextTask = provider.getNextTask();
    final currentTime = TimeOfDay.now();
    final formattedTime = _formatTimeOfDay(currentTime);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background,
            AppColors.background.withOpacity(0.8),
          ],
        ),
      ),
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current time display
              Container(
                margin: EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: AppColors.primary.withOpacity(0.7),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current time: $formattedTime',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.primary.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Current task section
              Text(
                "What's happening now",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onBackground,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 16),
              currentTask != null ? _buildCurrentTaskCard(currentTask) : _buildEmptyTaskCard('No task scheduled', Icons.free_breakfast_rounded),

              // Progress indicator
              if (currentTask != null && provider.getTodayEntries().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Today\'s progress',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.onBackground.withOpacity(0.7),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(provider.getCurrentProgressInDay() * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: provider.getCurrentProgressInDay(),
                          minHeight: 8,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),

              // Next task section
              SizedBox(height: 8),
              Text(
                "Coming up next",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onBackground,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 16),
              nextTask != null ? _buildNextTaskCard(nextTask) : _buildEmptyTaskCard('No upcoming tasks today', Icons.event_available_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTaskCard(TimetableEntry task) {
    final color = _getColorForTask(task.taskName);
    final icon = _getIconForTask(task.taskName);
    final remainingTime = _getRemainingTime(task);

    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: color,
              width: 6,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: color,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.taskName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${_formatTimeOfDay(task.startTime)} - ${_formatTimeOfDay(task.endTime)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (task.notes != null && task.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notes_rounded,
                          size: 18,
                          color: AppColors.onSurface.withOpacity(0.5),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.notes!,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: color,
                    ),
                    SizedBox(width: 6),
                    Text(
                      remainingTime,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextTaskCard(TimetableEntry task) {
    final color = _getColorForTask(task.taskName);
    final icon = _getIconForTask(task.taskName);

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.taskName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${_formatTimeOfDay(task.startTime)} - ${_formatTimeOfDay(task.endTime)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Next',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            if (task.notes != null && task.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 44),
                child: Text(
                  task.notes!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurface.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTaskCard(String message, IconData icon) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: AppColors.onSurface.withOpacity(0.3),
              ),
            ),
            SizedBox(width: 16),
            // Added Expanded to fix overflow
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.onSurface.withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 64,
              color: AppColors.onBackground.withOpacity(0.2),
            ),
            SizedBox(height: 16),
            Text(
              'No tasks scheduled for today',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.onBackground.withOpacity(0.6),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddEntryDialog(context),
              icon: Icon(Icons.add_rounded),
              label: Text('Add Your First Task'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: ListView.builder(
        itemCount: todayEntries.length + 1, // +1 for the header
        padding: const EdgeInsets.all(20),
        physics: BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Header with day and date
            final now = DateTime.now();
            final dayName = DateFormat('EEEE').format(now);
            final date = DateFormat('MMMM d, y').format(now);

            return Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.onBackground.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 16),
                  Divider(),
                ],
              ),
            );
          }

          final entry = todayEntries[index - 1];
          final isCurrentTask = provider.isCurrentTask(entry);
          final color = _getColorForTask(entry.taskName);
          final icon = _getIconForTask(entry.taskName);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              elevation: isCurrentTask ? 3 : 1,
              shadowColor: isCurrentTask ? color.withOpacity(0.3) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isCurrentTask ? BorderSide(color: color, width: 2) : BorderSide.none,
              ),
              child: InkWell(
                onTap: () => _showTaskDetailsBottomSheet(context, entry),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time column
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTimeOfDayShort(entry.startTime),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isCurrentTask ? color : AppColors.onSurface.withOpacity(0.7),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            width: 2,
                            height: 20,
                            color: color.withOpacity(0.3),
                          ),
                          Text(
                            _formatTimeOfDayShort(entry.endTime),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isCurrentTask ? color : AppColors.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),

                      // Vertical line
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 12),
                        width: 1,
                        height: 80,
                        color: AppColors.onSurface.withOpacity(0.1),
                      ),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 20,
                                    color: color,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    entry.taskName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isCurrentTask ? FontWeight.bold : FontWeight.w600,
                                      color: AppColors.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (entry.notes != null && entry.notes!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0, left: 40),
                                child: Text(
                                  entry.notes!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.onSurface.withOpacity(0.7),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Actions
                      Column(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: AppColors.onSurface.withOpacity(0.5),
                            ),
                            onPressed: () => _showEditEntryDialog(context, entry),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.all(8),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: AppColors.onSurface.withOpacity(0.5),
                            ),
                            onPressed: () => _showDeleteConfirmationDialog(context, entry),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.all(8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTaskDetailsBottomSheet(BuildContext context, TimetableEntry entry) {
    final color = _getColorForTask(entry.taskName);
    final icon = _getIconForTask(entry.taskName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: color,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.taskName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${_formatTimeOfDay(entry.startTime)} - ${_formatTimeOfDay(entry.endTime)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.notes!,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditEntryDialog(context, entry),
                      icon: Icon(Icons.edit_rounded),
                      label: Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteConfirmationDialog(context, entry);
                      },
                      icon: Icon(Icons.delete_rounded),
                      label: Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.onError,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab(TimetableProvider provider) {
    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(20.0),
        physics: BouncingScrollPhysics(),
        children: [
          // Profile section
          // Container(
          //   padding: EdgeInsets.all(20),
          //   decoration: BoxDecoration(
          //     gradient: LinearGradient(
          //       colors: [
          //         AppColors.primary,
          //         AppColors.primaryVariant
          //       ],
          //       begin: Alignment.topLeft,
          //       end: Alignment.bottomRight,
          //     ),
          //     borderRadius: BorderRadius.circular(16),
          //   ),
          //   child: Row(
          //     children: [
          //       CircleAvatar(
          //         radius: 30,
          //         backgroundColor: Colors.white.withOpacity(0.2),
          //         child: Icon(
          //           Icons.person_rounded,
          //           size: 36,
          //           color: Colors.white,
          //         ),
          //       ),
          //       SizedBox(width: 16),
          //       Expanded(
          //         child: Column(
          //           crossAxisAlignment: CrossAxisAlignment.start,
          //           children: [
          //             Text(
          //               'Routino',
          //               style: TextStyle(
          //                 fontSize: 22,
          //                 fontWeight: FontWeight.bold,
          //                 color: Colors.white,
          //               ),
          //               overflow: TextOverflow.ellipsis,
          //             ),
          //             Text(
          //               'Your personal schedule assistant',
          //               style: TextStyle(
          //                 fontSize: 14,
          //                 color: Colors.white.withOpacity(0.8),
          //               ),
          //               overflow: TextOverflow.ellipsis,
          //             ),
          //           ],
          //         ),
          //       ),
          //     ],
          //   ),
          // ),

          SizedBox(height: 24),

          // Notifications section
          _buildSettingsSection(
            title: 'Notifications',
            icon: Icons.notifications_rounded,
            color: AppColors.secondary,
            children: [
              SwitchListTile(
                title: Text(
                  'Enable notifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Get notified before tasks begin',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurface.withOpacity(0.7),
                  ),
                ),
                value: provider.notificationsEnabled,
                onChanged: (bool value) {
                  provider.setNotificationsEnabled(value, context);
                  if (value) {
                    provider.scheduleNotifications(_notificationsPlugin);
                  }
                },
                activeColor: AppColors.secondary,
              ),
            ],
          ),

          SizedBox(height: 16),

          // Day view settings
          _buildSettingsSection(
            title: 'Day View Settings',
            icon: Icons.calendar_view_day_rounded,
            color: AppColors.work,
            children: [
              ListTile(
                title: Text(
                  'Choose Day to View',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Currently showing: ${provider.selectedDay}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurface.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Container(
                  constraints: BoxConstraints(maxWidth: 100),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.work.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    provider.selectedDay,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.work,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onTap: () => _showDaySelectionDialog(context, provider),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Data management
          _buildSettingsSection(
            title: 'Data Management',
            icon: Icons.storage_rounded,
            color: AppColors.error,
            children: [
              ListTile(
                title: Text(
                  'Reset Timetable',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Delete all timetable entries',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurface.withOpacity(0.7),
                  ),
                ),
                trailing: Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.error,
                ),
                onTap: () => _showResetConfirmationDialog(context),
              ),
            ],
          ),

          SizedBox(height: 24),
          
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: color,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  void _showAddEntryDialog(BuildContext context) {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();

    // Initial values
    String day = 'Monday';
    String taskName = '';
    TimeOfDay startTime = TimeOfDay.now();
    TimeOfDay endTime = TimeOfDay(
      hour: TimeOfDay.now().hour + 1,
      minute: TimeOfDay.now().minute,
    );
    String? notes;

    // Value notifiers for reactive updates
    final dayNotifier = ValueNotifier<String>(day);
    final startTimeNotifier = ValueNotifier<TimeOfDay>(startTime);
    final endTimeNotifier = ValueNotifier<TimeOfDay>(endTime);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.add_task_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add New Task',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Day dropdown
                    ValueListenableBuilder<String>(
                      valueListenable: dayNotifier,
                      builder: (context, value, child) {
                        return DropdownButtonFormField<String>(
                          value: value,
                          decoration: InputDecoration(
                            labelText: 'Day of the Week',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: Icon(Icons.calendar_today_rounded),
                          ),
                          items: const [
                            'Monday',
                            'Tuesday',
                            'Wednesday',
                            'Thursday',
                            'Friday',
                            'Saturday',
                            'Sunday',
                          ].map((String day) {
                            return DropdownMenuItem<String>(
                              value: day,
                              child: Text(day),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              dayNotifier.value = newValue;
                              day = newValue;
                            }
                          },
                        );
                      },
                    ),

                    SizedBox(height: 16),

                    // Task name field
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Task Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.assignment_rounded),
                      ),
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

                    SizedBox(height: 16),

                    // Start time
                    ValueListenableBuilder<TimeOfDay>(
                      valueListenable: startTimeNotifier,
                      builder: (context, value, child) {
                        return InkWell(
                          onTap: () async {
                            final pickedTime = await showTimePicker(
                              context: dialogContext,
                              initialTime: value,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: AppColors.primary,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (pickedTime != null) {
                              startTimeNotifier.value = pickedTime;
                              startTime = pickedTime;
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Start Time',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.access_time_rounded),
                            ),
                            child: Text(_formatTimeOfDay(value)),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 16),

                    // End time
                    ValueListenableBuilder<TimeOfDay>(
                      valueListenable: endTimeNotifier,
                      builder: (context, value, child) {
                        return InkWell(
                          onTap: () async {
                            final pickedTime = await showTimePicker(
                              context: dialogContext,
                              initialTime: value,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: AppColors.primary,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (pickedTime != null) {
                              endTimeNotifier.value = pickedTime;
                              endTime = pickedTime;
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'End Time',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.access_time_filled_rounded),
                            ),
                            child: Text(_formatTimeOfDay(value)),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 16),

                    // Notes field
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        notes = value;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel'),
            ),
            ElevatedButton.icon(
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
                  Navigator.pop(dialogContext);

                  // Show success notification
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Task "$taskName" added successfully for $day'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: Icon(Icons.save_rounded),
              label: Text('Add Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    ).then((_) {
      // Clean up
      dayNotifier.dispose();
      startTimeNotifier.dispose();
      endTimeNotifier.dispose();
    });
  }

  void _showEditEntryDialog(BuildContext context, TimetableEntry entry) {
    // Implementation similar to _showAddEntryDialog but with pre-filled values
    // and updating instead of adding a new entry
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
          title: Row(
            children: [
              Icon(
                Icons.edit_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Edit Task',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Similar form fields as in _showAddEntryDialog but with initial values
                    // from the entry being edited
                    DropdownButtonFormField<String>(
                      value: day,
                      decoration: InputDecoration(
                        labelText: 'Day of the Week',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                      ),
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
                        if (newValue != null) {
                          day = newValue;
                        }
                      },
                    ),

                    SizedBox(height: 16),

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Task Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.assignment_rounded),
                      ),
                      initialValue: taskName,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a task name';
                        }
                        return null;
                      },
                      onChanged: (value) => taskName = value,
                    ),

                    SizedBox(height: 16),

                    InkWell(
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppColors.primary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedTime != null) {
                          setState(() => startTime = pickedTime);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start Time',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.access_time_rounded),
                        ),
                        child: Text(_formatTimeOfDay(startTime)),
                      ),
                    ),

                    SizedBox(height: 16),

                    InkWell(
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppColors.primary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedTime != null) {
                          setState(() => endTime = pickedTime);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End Time',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.access_time_filled_rounded),
                        ),
                        child: Text(_formatTimeOfDay(endTime)),
                      ),
                    ),

                    SizedBox(height: 16),

                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                      initialValue: notes,
                      maxLines: 3,
                      onChanged: (value) => notes = value,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton.icon(
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
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Task "$taskName" updated successfully'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.blue,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: Icon(Icons.save_rounded),
              label: Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, TimetableEntry entry) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delete Task',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${entry.taskName}"? This action cannot be undone.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final taskName = entry.taskName;
                final day = entry.day;
                Provider.of<TimetableProvider>(context, listen: false).deleteEntry(entry);
                Navigator.pop(context);

                // Show success notification for delete
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Task "$taskName" deleted from $day'),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(Icons.delete_rounded),
              label: Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  void _showResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.delete_forever_rounded,
                color: AppColors.error,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reset Timetable',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete all timetable entries? This action cannot be undone.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Provider.of<TimetableProvider>(context, listen: false).resetTimetable();
                Navigator.pop(context);

                // Show notification for reset
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Timetable has been reset'),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(Icons.delete_sweep_rounded),
              label: Text('Reset'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  void _showDaySelectionDialog(BuildContext context, TimetableProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Select Day',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
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
                final isSelected = provider.selectedDay == day;
                return ListTile(
                  title: Text(
                    day,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  leading: Icon(
                    Icons.calendar_today_rounded,
                    color: isSelected ? AppColors.primary : Colors.grey,
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () {
                    provider.setSelectedDay(day);
                    Navigator.pop(context);
                  },
                  selected: isSelected,
                  selectedTileColor: AppColors.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }).toList(),
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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

  String _formatTimeOfDayShort(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm').format(dt);
  }

  String _getRemainingTime(TimetableEntry task) {
    final now = DateTime.now();
    final endTime = DateTime(
      now.year,
      now.month,
      now.day,
      task.endTime.hour,
      task.endTime.minute,
    );

    final difference = endTime.difference(now);

    if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m remaining';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m remaining';
    } else {
      return 'Ending soon';
    }
  }

  IconData _getIconForTask(String taskName) {
    final taskLower = taskName.toLowerCase();
    if (taskLower.contains('study') || taskLower.contains('class') || taskLower.contains('lecture')) {
      return Icons.school_rounded;
    } else if (taskLower.contains('break') || taskLower.contains('lunch') || taskLower.contains('rest')) {
      return Icons.free_breakfast_rounded;
    } else if (taskLower.contains('exercise') || taskLower.contains('gym') || taskLower.contains('workout')) {
      return Icons.fitness_center_rounded;
    } else if (taskLower.contains('meeting') || taskLower.contains('appointment')) {
      return Icons.people_rounded;
    } else if (taskLower.contains('work') || taskLower.contains('project')) {
      return Icons.work_rounded;
    } else {
      return Icons.event_note_rounded;
    }
  }

  Color _getColorForTask(String taskName) {
    final taskLower = taskName.toLowerCase();
    if (taskLower.contains('study') || taskLower.contains('class') || taskLower.contains('lecture')) {
      return AppColors.study;
    } else if (taskLower.contains('break') || taskLower.contains('lunch') || taskLower.contains('rest')) {
      return AppColors.leisure;
    } else if (taskLower.contains('exercise') || taskLower.contains('gym') || taskLower.contains('workout')) {
      return AppColors.exercise;
    } else if (taskLower.contains('meeting') || taskLower.contains('appointment')) {
      return AppColors.meeting;
    } else if (taskLower.contains('work') || taskLower.contains('project')) {
      return AppColors.work;
    } else {
      return AppColors.other;
    }
  }
}
