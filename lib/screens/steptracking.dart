import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../services/step_service.dart';

class StepTrackingScreen extends StatefulWidget {
  const StepTrackingScreen({super.key});

  @override
  State<StepTrackingScreen> createState() => _StepTrackingScreenState();
}

class _StepTrackingScreenState extends State<StepTrackingScreen> {
  final StepService _stepService = StepService();
  int _steps = 0;
  double _calories = 0;
  int _minutes = 0;
  double _distance = 0;
  int _goalSteps = 10000;
  StreamSubscription<int>? _stepSubscription;
  List<MapEntry<String, int>> _history = [];
  bool _isPaused = false;
  Map<String, dynamic> _activityStats = {};
  Map<String, int> _weeklyStats = {};

  @override
  void initState() {
    super.initState();
    _initializeStepTracking();
  }

  Future<void> _initializeStepTracking() async {
    final activityPermission = await Permission.activityRecognition.request();
    final notificationPermission = await Permission.notification.request();

    if (activityPermission.isGranted && notificationPermission.isGranted) {
      await _stepService.initialize();
      await _loadData();
      _stepSubscription = _stepService.stepStream.listen(_onStepUpdate);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions required for step tracking'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onStepUpdate(int steps) {
    setState(() {
      _steps = steps;
      _calories = _calculateCalories(steps);
      _minutes = _calculateMinutes(steps);
      _distance = _calculateDistance(steps);
    });
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _stepService.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await _stepService.getActivityStats();
    final weeklyStats = await _stepService.getWeeklyStats();
    if (!mounted) return;
    setState(() {
      _activityStats = stats;
      _weeklyStats = weeklyStats;
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final steps = prefs.getInt('steps') ?? 0;
    final goalSteps = prefs.getInt('goal_steps') ?? 10000;
    final history = prefs.getStringList('step_history') ?? [];

    await _loadStats(); // Load additional stats

    if (!mounted) return;
    setState(() {
      _steps = steps;
      _goalSteps = goalSteps;
      _calories = _calculateCalories(steps);
      _minutes = _calculateMinutes(steps);
      _distance = _calculateDistance(steps);
      _history = history
          .map((e) => MapEntry(e.split(':')[0], int.parse(e.split(':')[1])))
          .toList()
        ..sort((a, b) => b.key.compareTo(a.key)); // Sort by date descending
    });
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _isPaused ? Icons.play_arrow : Icons.pause,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(_isPaused ? 'Resume Tracking' : 'Pause Tracking'),
              onTap: () {
                if (_isPaused) {
                  _stepService.resumeTracking();
                } else {
                  _stepService.pauseTracking();
                }
                setState(() => _isPaused = !_isPaused);
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.flag,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Set Daily Goal'),
              onTap: () {
                Navigator.pop(context);
                _setGoal();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.restart_alt,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Reset Steps'),
              onTap: () {
                _stepService.resetSteps();
                Navigator.pop(context);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCircle(ThemeData theme) {
    return Container(
      height: 250,
      width: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withAlpha(50),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 220,
            width: 220,
            child: CircularProgressIndicator(
              value: _steps / _goalSteps,
              strokeWidth: 12,
              backgroundColor: theme.colorScheme.primaryContainer,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _steps.toString(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Goal: $_goalSteps',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateCalories(int steps) {
    // Rough estimation: 0.04 calories per step
    return (steps * 0.04).roundToDouble();
  }

  int _calculateMinutes(int steps) {
    // Rough estimation: 1 minute per 100 steps
    return (steps ~/ 100);
  }

  double _calculateDistance(int steps) {
    // Rough estimation: 0.0008 km per step
    return (steps * 0.0008).roundToDouble();
  }

  Future<void> _setGoal() async {
    final controller = TextEditingController(text: _goalSteps.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Daily Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Steps Goal',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final goal = int.tryParse(controller.text);
              if (goal != null && goal > 0) {
                Navigator.pop(context, goal);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('goal_steps', result);
      setState(() => _goalSteps = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Steps Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsMenu,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _buildProgressCircle(theme)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Calories',
                    value: _calories.toString(),
                    unit: 'kcal',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Time',
                    value: _minutes.toString(),
                    unit: 'min',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Distance',
                    value: _distance.toString(),
                    unit: 'km',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'History',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 24),
            Text(
              'Weekly Progress',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Average: ${_activityStats['weekly_average'] ?? 0} steps',
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: _weeklyStats.entries.map((entry) {
                            final percentage = entry.value / _goalSteps;
                            return Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: FractionallySizedBox(
                                      heightFactor: percentage.clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withAlpha(179),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.key.split('-').last,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildHistoryCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String unit,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          ..._history.take(7).map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      '${entry.value} steps',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
