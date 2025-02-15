import 'dart:async';
import 'dart:math' show sqrt;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class StepService {
  static final StepService _instance = StepService._();
  factory StepService() => _instance;
  StepService._();

  static const _stepThreshold = 10.0;
  static const _samplingRate = Duration(milliseconds: 20);
  static const _backgroundTaskId = "step-tracking";
  static const _backgroundTaskName = "stepTracking";

  final _stepController = StreamController<int>.broadcast();
  Stream<int> get stepStream => _stepController.stream;

  Timer? _timer;
  double _lastMagnitude = 0;
  bool _isStepUp = false;
  DateTime? _lastStepTime;
  bool _isTracking = false;

  Future<void> initialize() async {
    try {
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
      await _registerBackgroundTask();
      await _startTracking();
    } catch (e) {
      debugPrint('Error initializing step service: $e');
    }
  }

  Future<void> _registerBackgroundTask() async {
    await Workmanager().registerPeriodicTask(
      _backgroundTaskId,
      _backgroundTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: true,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      backoffPolicy: BackoffPolicy.linear,
      existingWorkPolicy: ExistingWorkPolicy.keep,
      initialDelay: const Duration(seconds: 10),
    );
  }

  Future<void> _startTracking() async {
    if (_isTracking) return;
    _isTracking = true;

    accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval)
        .listen((event) {
      final magnitude = _calculateMagnitude(event);
      _detectStep(magnitude);
    });

    _timer = Timer.periodic(_samplingRate, (_) {
      _saveSteps();
    });

    // Load initial steps
    final prefs = await SharedPreferences.getInstance();
    final steps = prefs.getInt('steps') ?? 0;
    _stepController.add(steps);
  }

  Future<void> resetSteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('steps', 0);
    _stepController.add(0);
  }

  Future<void> pauseTracking() async {
    _isTracking = false;
    _timer?.cancel();
  }

  Future<void> resumeTracking() async {
    await _startTracking();
  }

  double _calculateMagnitude(AccelerometerEvent event) {
    return sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
  }

  void _detectStep(double magnitude) {
    if (_lastStepTime != null) {
      final timeDiff = DateTime.now().difference(_lastStepTime!);
      if (timeDiff.inMilliseconds < 300) return; // Increased debounce time
    }

    // Improved step detection with dynamic threshold
    final dynamicThreshold = _calculateDynamicThreshold(magnitude);

    if (!_isStepUp &&
        magnitude > _lastMagnitude &&
        magnitude > dynamicThreshold) {
      _isStepUp = true;
    } else if (_isStepUp &&
        magnitude < _lastMagnitude &&
        magnitude < dynamicThreshold) {
      _isStepUp = false;
      _onStepDetected();
    }
    _lastMagnitude = magnitude;
  }

  double _calculateDynamicThreshold(double currentMagnitude) {
    // Adaptive threshold based on recent movement
    return _stepThreshold *
        (1 + (currentMagnitude - _lastMagnitude).abs() / 20);
  }

  void _onStepDetected() {
    _lastStepTime = DateTime.now();
    _incrementSteps();
  }

  Future<void> _incrementSteps() async {
    final prefs = await SharedPreferences.getInstance();
    final currentSteps = prefs.getInt('steps') ?? 0;
    final newSteps = currentSteps + 1;
    await prefs.setInt('steps', newSteps);
    _stepController.add(newSteps);
  }

  Future<void> _saveSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentSteps = prefs.getInt('steps') ?? 0;

      final today = DateTime.now().toIso8601String().split('T')[0];
      final history = prefs.getStringList('step_history') ?? [];
      final historyMap = Map<String, int>.fromEntries(
        history.map((e) {
          final parts = e.split(':');
          return parts.length == 2
              ? MapEntry(parts[0], int.tryParse(parts[1]) ?? 0)
              : MapEntry(today, 0);
        }),
      );
      historyMap[today] = currentSteps;

      await prefs.setStringList(
        'step_history',
        historyMap.entries.map((e) => '${e.key}:${e.value}').toList(),
      );
    } catch (e) {
      debugPrint('Error saving steps: $e');
    }
  }

  Future<Map<String, int>> getWeeklyStats() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('step_history') ?? [];
    final stats = <String, int>{};

    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      stats[dateStr] = 0;
    }

    for (final entry in history) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        final date = parts[0];
        final steps = int.tryParse(parts[1]) ?? 0;
        if (stats.containsKey(date)) {
          stats[date] = steps;
        }
      }
    }

    return stats;
  }

  Future<Map<String, dynamic>> getActivityStats() async {
    final prefs = await SharedPreferences.getInstance();
    final steps = prefs.getInt('steps') ?? 0;
    final goalSteps = prefs.getInt('goal_steps') ?? 10000;
    final weeklyStats = await getWeeklyStats();
    final weeklyAverage = weeklyStats.values.isEmpty
        ? 0
        : weeklyStats.values.reduce((a, b) => a + b) ~/ weeklyStats.length;

    return {
      'current_steps': steps,
      'goal_steps': goalSteps,
      'weekly_average': weeklyAverage,
      'calories_burned': (steps * 0.04).round(),
      'distance_km': (steps * 0.0008).toStringAsFixed(2),
      'active_minutes': (steps ~/ 100),
      'goal_progress': (steps / goalSteps * 100).round(),
    };
  }

  void dispose() {
    _timer?.cancel();
    _stepController.close();
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case "stepTracking":
        final stepService = StepService();
        await stepService.initialize();
        return true;
      default:
        return false;
    }
  });
}
