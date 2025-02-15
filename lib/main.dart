import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'services/first_launch_service.dart';

import 'models/todo.dart';
import 'models/note.dart';
import 'screens/welcome_screen.dart';
import 'screens/onboarding_screen.dart';

import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'screens/todo_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/more_section.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('dark_mode') ?? false;
  bool notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
  final isFirstLaunch = await FirstLaunchService.isFirstLaunch();

  // Request and check all required permissions
  Map<Permission, PermissionStatus> permissions = await [
    Permission.notification,
    Permission.scheduleExactAlarm,
    Permission.activityRecognition,
  ].request();

  // Check each permission and log the status
  permissions.forEach((permission, status) {
    debugPrint('Permission ${permission.toString()}: ${status.toString()}');
  });

  // Initialize notification service
  final notificationService = NotificationService();
  bool isInitialized = false;

  try {
    isInitialized = await notificationService.initialize();
    debugPrint('Notification service initialized: $isInitialized');
  } catch (e) {
    debugPrint('Failed to initialize notification service: $e');
  }

  // Check if all required permissions are granted
  bool allPermissionsGranted =
      permissions.values.every((status) => status.isGranted);

  if (!isInitialized || !allPermissionsGranted) {
    notificationsEnabled = false;
    await prefs.setBool('notifications_enabled', false);

    // Detailed error logging
    if (!isInitialized) {
      debugPrint('Notifications disabled: Service initialization failed');
    }
    if (!allPermissionsGranted) {
      permissions.forEach((permission, status) {
        if (!status.isGranted) {
          debugPrint('Missing permission: ${permission.toString()}');
        }
      });
    }
  }

  // Store permission status for later use
  await prefs.setBool('permissions_granted', allPermissionsGranted);

  runApp(MyApp(
    isDarkMode: isDarkMode,
    notificationsEnabled: notificationsEnabled,
    isFirstLaunch: isFirstLaunch,
  ));
}

class MyApp extends StatefulWidget {
  final bool isDarkMode;
  final bool notificationsEnabled;
  final bool isFirstLaunch;

  const MyApp({
    super.key,
    required this.isDarkMode,
    required this.notificationsEnabled,
    required this.isFirstLaunch,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDarkMode;
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _notificationsEnabled = widget.notificationsEnabled;
  }

  void _updateTheme(bool isDarkMode) {
    setState(() {
      _isDarkMode = isDarkMode;
    });
  }

  void _updateNotifications(bool enabled) {
    setState(() {
      _notificationsEnabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
      routes: {
        '/home': (context) => HomePage(
              onThemeChanged: _updateTheme,
              onNotificationsChanged: _updateNotifications,
              notificationsEnabled: _notificationsEnabled,
              themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
            ),
      },
    );
  }
}

class WeatherInfo {
  final double temperature;
  final String condition;
  final String iconCode;

  WeatherInfo({
    required this.temperature,
    required this.condition,
    required this.iconCode,
  });
}

class HomePage extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final Function(bool) onNotificationsChanged;
  final bool notificationsEnabled;
  final ThemeMode themeMode;

  const HomePage({
    super.key,
    required this.onThemeChanged,
    required this.onNotificationsChanged,
    required this.notificationsEnabled,
    required this.themeMode,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final StorageService _storage = StorageService();
  List<Todo> _todos = [];
  List<Note> _notes = [];
  int _currentIndex = 0;
  DateTime _now = DateTime.now();
  Timer? _timer;
  Map<String, dynamic> _youtubeMetrics = {
    'videosCreated': 0,
    'monthlyGrowth': 0,
    'nextVideoDue': '',
    'status': 'On track',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    _updateTime();
    _loadYouTubeMetrics();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    setState(() {
      _now = DateTime.now();
    });
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 1), _updateTime);
  }

  Future<void> _loadData() async {
    final todos = await _storage.loadTodos();
    final notes = await _storage.loadNotes();
    setState(() {
      _todos = todos;
      _notes = notes;
    });
  }

  Future<void> _loadYouTubeMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _youtubeMetrics = {
        'videosCreated': prefs.getInt('youtube_videos_created') ?? 0,
        'monthlyGrowth': prefs.getInt('youtube_monthly_growth') ?? 0,
        'nextVideoDue': prefs.getString('youtube_next_video') ?? 'Not set',
        'status': prefs.getString('youtube_status') ?? 'On track',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            HomeContent(
              todos: _todos,
              notes: _notes,
              now: _now,
              youtubeMetrics: _youtubeMetrics,
            ),
            const TodoScreen(),
            MoreSection(
              onThemeChanged: widget.onThemeChanged,
              themeMode: widget.themeMode,
            ),
            const NotesScreen(),
            SettingsScreen(
              onThemeChanged: widget.onThemeChanged,
              onNotificationsChanged: widget.onNotificationsChanged,
              notificationsEnabled: widget.notificationsEnabled,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'To Do List',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_4x4),
            label: 'More',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note),
            label: 'Note',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Setting',
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  final List<Todo> todos;
  final List<Note> notes;
  final DateTime now;
  final Map<String, dynamic> youtubeMetrics;

  const HomeContent({
    super.key,
    required this.todos,
    required this.notes,
    required this.now,
    required this.youtubeMetrics,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _refreshTimer;
  WeatherInfo? _weatherInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
    _startRefreshTimer();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    // Simulate weather data for demo
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _weatherInfo = WeatherInfo(
          temperature: 22.5,
          condition: 'Partly Cloudy',
          iconCode: '02d',
        );
        _isLoading = false;
      });
    }
  }

  Widget _buildWeatherWidget(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Icon(
                  Icons.wb_sunny,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_weatherInfo!.temperature.toStringAsFixed(1)}°C',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      _weatherInfo!.condition,
                      style: TextStyle(
                        color:
                            theme.colorScheme.onPrimaryContainer.withAlpha(179),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: RefreshIndicator(
        onRefresh: () async {
          if (context.findAncestorStateOfType<_HomePageState>() != null) {
            await context
                .findAncestorStateOfType<_HomePageState>()!
                ._loadData();
            await _loadWeather();
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGreeting(context),
            const SizedBox(height: 16),
            _buildWeatherWidget(context),
            const SizedBox(height: 16),
            _buildQuickActions(context),
            const SizedBox(height: 16),
            _buildTodoSection(context),
            const SizedBox(height: 16),
            _buildNotesSection(context),
            const SizedBox(height: 16),
            _buildYouTubeSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final pendingTodos = widget.todos.where((todo) => !todo.isCompleted).length;
    final pendingNotes = widget.notes
        .where((note) =>
            note.notificationDate != null &&
            note.notificationDate!.isAfter(DateTime.now()))
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickAction(
            context,
            icon: Icons.add_task,
            label: 'New Todo',
            onTap: () => _navigateToIndex(context, 1),
            badge: pendingTodos > 0 ? pendingTodos.toString() : null,
          ),
          _buildQuickAction(
            context,
            icon: Icons.note_add,
            label: 'New Note',
            onTap: () => _navigateToIndex(context, 3),
            badge: pendingNotes > 0 ? pendingNotes.toString() : null,
          ),
          _buildQuickAction(
            context,
            icon: Icons.more_horiz,
            label: 'More',
            onTap: () => _navigateToIndex(context, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? badge,
  }) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: -5,
            top: -5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Center(
                child: Text(
                  badge,
                  style: TextStyle(
                    color: theme.colorScheme.onError,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _navigateToIndex(BuildContext context, int index) {
    if (context.findAncestorStateOfType<_HomePageState>() != null) {
      context.findAncestorStateOfType<_HomePageState>()!.setState(() => context
          .findAncestorStateOfType<_HomePageState>()!
          ._currentIndex = index);
    }
  }

  Widget _buildGreeting(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(51),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            ),
            child: Text(
              'Good ${_getGreeting()}',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - value)),
                child: child,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: theme.colorScheme.onPrimary.withAlpha(204),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('hh:mm a   MM/dd/yyyy').format(widget.now),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _getDayProgress(),
            backgroundColor: theme.colorScheme.onPrimary.withAlpha(26),
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.onPrimary.withAlpha(204),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getDayProgressText(),
            style: TextStyle(
              color: theme.colorScheme.onPrimary.withAlpha(204),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  double _getDayProgress() {
    final now = widget.now;
    return (now.hour * 3600 + now.minute * 60 + now.second) / 86400;
  }

  String _getDayProgressText() {
    final progress = _getDayProgress() * 100;
    final hoursLeft = ((1 - _getDayProgress()) * 24).round();
    return '${progress.toStringAsFixed(1)}% of day complete • $hoursLeft hours remaining';
  }

  String _getGreeting() {
    final hour = widget.now.hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Widget _buildTodoSection(BuildContext context) {
    final theme = Theme.of(context);
    final pendingTodos = widget.todos.where((todo) => !todo.isCompleted).length;
    final completedTodos =
        widget.todos.where((todo) => todo.isCompleted).length;
    final progress =
        widget.todos.isEmpty ? 0.0 : completedTodos / widget.todos.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To Do List',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 1500),
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  backgroundColor: theme.colorScheme.primary.withAlpha(51),
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressItem(
            context,
            icon: Icons.pending_actions,
            label: 'Pending',
            value: pendingTodos,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 8),
          _buildProgressItem(
            context,
            icon: Icons.check_circle_outline,
            label: 'Completed',
            value: completedTodos,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const Spacer(),
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline,
                    color: theme.colorScheme.primary),
                onPressed: () => _navigateToIndex(context, 3),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.notes.isEmpty)
            Center(
              child: Text(
                'No notes yet',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer.withAlpha(153),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.notes.length.clamp(0, 3),
              itemBuilder: (context, index) {
                final note = widget.notes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.note,
                          color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note.headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      if (note.notificationDate != null)
                        Icon(Icons.notifications_active,
                            color: theme.colorScheme.primary, size: 16),
                    ],
                  ),
                );
              },
            ),
          if (widget.notes.length > 3) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _navigateToIndex(context, 3),
                child: Text('View all ${widget.notes.length} notes'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildYouTubeSection(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YouTube Strategy',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              IconButton(
                icon: Icon(Icons.play_circle_outline,
                    color: theme.colorScheme.primary),
                onPressed: () => _navigateToIndex(context, 2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildYouTubeMetric(
            context,
            icon: Icons.video_library,
            label: 'Videos Created',
            value: widget.youtubeMetrics['videosCreated'].toString(),
            trend: '+${widget.youtubeMetrics['monthlyGrowth']} this month',
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _buildYouTubeMetric(
            context,
            icon: Icons.schedule,
            label: 'Next Video Due',
            value: widget.youtubeMetrics['nextVideoDue'],
            trend: widget.youtubeMetrics['status'],
            color: theme.colorScheme.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildYouTubeMetric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String trend,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    trend,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
