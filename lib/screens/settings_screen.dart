import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'about.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';
import '../models/todo.dart';
import '../models/note.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final Function(bool) onNotificationsChanged;
  final bool notificationsEnabled;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.onNotificationsChanged,
    required this.notificationsEnabled,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();
  bool _notificationsEnabled = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.notificationsEnabled;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _isDarkMode = prefs.getBool('dark_mode') ?? false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading settings: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', value);
      widget.onNotificationsChanged(value);
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = value;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error toggling notifications: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', value);
      widget.onThemeChanged(value);
      if (!mounted) return;
      setState(() {
        _isDarkMode = value;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error toggling theme: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  bool _validateJsonStructure(Map<String, dynamic> json) {
    // Check if all required keys exist
    if (!json.containsKey('todos') ||
        !json.containsKey('notes') ||
        !json.containsKey('settings') ||
        !json.containsKey('calculator_history') ||
        !json.containsKey('links') ||
        !json.containsKey('passwords')) {
      return false;
    }

    // Validate settings structure
    final settings = json['settings'] as Map<String, dynamic>?;
    if (settings == null ||
        !settings.containsKey('notifications_enabled') ||
        !settings.containsKey('dark_mode') ||
        !settings.containsKey('step_history') ||
        !settings.containsKey('steps')) {
      return false;
    }

    // Validate data types
    if (json['todos'] is! List ||
        json['notes'] is! List ||
        json['calculator_history'] is! List ||
        json['links'] is! Map ||
        json['passwords'] is! List ||
        settings['notifications_enabled'] is! bool ||
        settings['dark_mode'] is! bool ||
        settings['step_history'] is! List ||
        settings['steps'] is! int) {
      return false;
    }

    return true;
  }

  Future<void> _importData() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a backup file to import...')),
      );

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected')),
        );
        return;
      }

      final file = File(result.files.single.path!);
      if (!file.existsSync()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected file does not exist'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show progress indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reading backup file...')),
      );

      final fileContent = await file.readAsString();
      final isJson = result.files.single.path!.toLowerCase().endsWith('.json');

      if (isJson) {
        await _importJsonData(fileContent);
      } else {
        await _importTextData(fileContent);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importTextData(String content) async {
    try {
      final lines = content.split('\n');
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = const FlutterSecureStorage();

      List<Todo> todos = [];
      List<Note> notes = [];
      List<String> calculatorHistory = [];
      Map<String, String> links = {};
      List<Map<String, String>> passwords = [];
      List<String> stepHistory = [];
      int steps = 0;

      String currentSection = '';
      Map<String, dynamic> currentItem = {};

      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        if (line.startsWith('=== ') && line.endsWith(' ===')) {
          // Save previous item if exists
          if (currentItem.isNotEmpty) {
            _saveCurrentItem(
                currentSection, currentItem, todos, notes, passwords);
            currentItem = {};
          }
          currentSection = line.replaceAll('===', '').trim();
          continue;
        }

        if (line.contains(':')) {
          final parts = line.split(':');
          final key = parts[0].trim();
          final value = parts.sublist(1).join(':').trim();

          switch (currentSection) {
            case 'TODOS':
            case 'NOTES':
            case 'PASSWORDS':
              currentItem[key.toLowerCase()] = value;
              break;
            case 'CALCULATOR HISTORY':
              calculatorHistory.add(line);
              break;
            case 'LINKS':
              links[key] = value;
              break;
            case 'STEP HISTORY':
              if (key == 'Current Steps') {
                steps = int.tryParse(value) ?? 0;
              } else {
                stepHistory.add(line);
              }
              break;
          }
        }
      }

      // Save the last item if exists
      if (currentItem.isNotEmpty) {
        _saveCurrentItem(currentSection, currentItem, todos, notes, passwords);
      }

      // Save all imported data
      await _storage.saveTodos(todos);
      await _storage.saveNotes(notes);
      await prefs.setStringList('calculator_history', calculatorHistory);
      await prefs.setStringList('platforms', links.keys.toList());
      for (final entry in links.entries) {
        await prefs.setString('link_${entry.key}', entry.value);
      }
      await secureStorage.write(key: 'passwords', value: jsonEncode(passwords));
      await prefs.setStringList('step_history', stepHistory);
      await prefs.setInt('steps', steps);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data imported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing text data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _saveCurrentItem(String section, Map<String, dynamic> item,
      List<Todo> todos, List<Note> notes, List<Map<String, String>> passwords) {
    switch (section) {
      case 'TODOS':
        if (item.containsKey('title')) {
          todos.add(Todo(
            id: DateTime.now().toString(),
            title: item['title'],
            isCompleted: item['completed']?.toLowerCase() == 'true',
            createdAt:
                DateTime.tryParse(item['created'] ?? '') ?? DateTime.now(),
            notificationDate: DateTime.tryParse(item['due'] ?? ''),
            priority: Priority.values.firstWhere(
              (p) => p
                  .toString()
                  .toLowerCase()
                  .contains(item['priority']?.toLowerCase() ?? ''),
              orElse: () => Priority.medium,
            ),
            category: item['category'],
          ));
        }
        break;
      case 'NOTES':
        if (item.containsKey('title') && item.containsKey('content')) {
          notes.add(Note(
            id: DateTime.now().toString(),
            headline: item['title'],
            description: item['content'],
            createdAt:
                DateTime.tryParse(item['created'] ?? '') ?? DateTime.now(),
            notificationDate: DateTime.tryParse(item['due'] ?? ''),
          ));
        }
        break;
      case 'PASSWORDS':
        if (item.containsKey('platform') && item.containsKey('password')) {
          passwords.add({
            'platform': item['platform'],
            'password': item['password'],
          });
        }
        break;
    }
  }

  Future<void> _importJsonData(String jsonString) async {
    try {
      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid JSON format in the selected file'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!_validateJsonStructure(jsonData)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid backup file format'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show progress indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Importing data...')),
      );

      // Import todos
      final todos = jsonData['todos'] as List;
      final importedTodos = todos.map((e) => Todo.fromJson(e)).toList();
      await _storage.saveTodos(importedTodos);

      // Import notes
      final notes = jsonData['notes'] as List;
      final importedNotes = notes.map((e) => Note.fromJson(e)).toList();
      await _storage.saveNotes(importedNotes);

      // Get SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();

      // Import calculator history
      final calculatorHistory = jsonData['calculator_history'] as List<dynamic>;
      await prefs.setStringList(
          'calculator_history', calculatorHistory.cast<String>());

      // Import links
      final links = jsonData['links'] as Map<String, dynamic>;
      final platforms = links.keys.toList();
      await prefs.setStringList('platforms', platforms);
      for (final platform in platforms) {
        await prefs.setString('link_$platform', links[platform] as String);
      }

      // Import passwords
      final passwords = jsonData['passwords'] as List;
      final secureStorage = const FlutterSecureStorage();
      await secureStorage.write(key: 'passwords', value: jsonEncode(passwords));

      // Import settings
      final settings = jsonData['settings'] as Map<String, dynamic>;
      await prefs.setBool(
          'notifications_enabled', settings['notifications_enabled'] as bool);
      await prefs.setBool('dark_mode', settings['dark_mode'] as bool);
      await prefs.setStringList(
          'step_history', List<String>.from(settings['step_history']));
      await prefs.setInt('steps', settings['steps'] as int);

      // Update UI state
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = settings['notifications_enabled'] as bool;
        _isDarkMode = settings['dark_mode'] as bool;
      });

      // Notify parent widgets
      widget.onNotificationsChanged(_notificationsEnabled);
      widget.onThemeChanged(_isDarkMode);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data imported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing JSON data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _convertDataToText() async {
    final todos = await _storage.loadTodos();
    final notes = await _storage.loadNotes();
    final prefs = await SharedPreferences.getInstance();
    final secureStorage = const FlutterSecureStorage();

    final buffer = StringBuffer();

    // Export Todos
    buffer.writeln('=== TODOS ===');
    for (final todo in todos) {
      buffer.writeln('Title: ${todo.title}');
      buffer.writeln('Completed: ${todo.isCompleted}');
      buffer.writeln('Created: ${todo.createdAt}');
      if (todo.notificationDate != null) {
        buffer.writeln('Due: ${todo.notificationDate}');
      }
      buffer.writeln('Priority: ${todo.priority}');
      if (todo.category != null) {
        buffer.writeln('Category: ${todo.category}');
      }
      buffer.writeln();
    }

    // Export Notes
    buffer.writeln('=== NOTES ===');
    for (final note in notes) {
      buffer.writeln('Title: ${note.headline}');
      buffer.writeln('Content: ${note.description}');
      buffer.writeln('Created: ${note.createdAt}');
      if (note.notificationDate != null) {
        buffer.writeln('Due: ${note.notificationDate}');
      }
      buffer.writeln();
    }

    // Export Calculator History
    buffer.writeln('=== CALCULATOR HISTORY ===');
    final calculatorHistory = prefs.getStringList('calculator_history') ?? [];
    for (final entry in calculatorHistory) {
      buffer.writeln(entry);
    }
    buffer.writeln();

    // Export Links
    buffer.writeln('=== LINKS ===');
    final platforms = prefs.getStringList('platforms') ?? [];
    for (final platform in platforms) {
      final link = prefs.getString('link_$platform') ?? '';
      buffer.writeln('$platform: $link');
    }
    buffer.writeln();

    // Export Steps
    buffer.writeln('=== STEP HISTORY ===');
    final stepHistory = prefs.getStringList('step_history') ?? [];
    final steps = prefs.getInt('steps') ?? 0;
    buffer.writeln('Current Steps: $steps');
    for (final entry in stepHistory) {
      buffer.writeln(entry);
    }
    buffer.writeln();

    // Export Passwords (securely stored)
    buffer.writeln('=== PASSWORDS ===');
    final passwordsJson = await secureStorage.read(key: 'passwords');
    if (passwordsJson != null) {
      final passwords = jsonDecode(passwordsJson) as List;
      for (final password in passwords) {
        buffer.writeln('Platform: ${password['platform']}');
        buffer.writeln('Password: ${password['password']}');
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  Future<void> _exportDataAsText() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing data for export...')),
      );

      final textData = await _convertDataToText();

      // Get save location from user
      final now = DateTime.now().toIso8601String().replaceAll(':', '-');
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save text backup file',
        fileName: 'app_data_export_$now.txt',
        allowedExtensions: ['txt'],
        type: FileType.custom,
      );

      if (outputFile == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export cancelled')),
        );
        return;
      }

      // Ensure file has .txt extension
      if (!outputFile.toLowerCase().endsWith('.txt')) {
        outputFile += '.txt';
      }

      // Write data
      final file = File(outputFile);
      await file.writeAsString(textData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data exported to ${file.path}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _exportData() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing data for export...')),
      );

      // Get all data
      final todos = await _storage.loadTodos();
      final notes = await _storage.loadNotes();
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = const FlutterSecureStorage();

      // Get calculator history
      final calculatorHistory = prefs.getStringList('calculator_history') ?? [];

      // Get links
      final platforms = prefs.getStringList('platforms') ?? [];
      final links = <String, String>{};
      for (final platform in platforms) {
        links[platform] = prefs.getString('link_$platform') ?? '';
      }

      // Get passwords (securely stored)
      final passwordsJson = await secureStorage.read(key: 'passwords');
      final passwords =
          passwordsJson != null ? jsonDecode(passwordsJson) as List : [];

      final exportData = {
        'todos': todos.map((todo) => todo.toJson()).toList(),
        'notes': notes.map((note) => note.toJson()).toList(),
        'calculator_history': calculatorHistory,
        'links': links,
        'passwords': passwords,
        'settings': {
          'notifications_enabled': _notificationsEnabled,
          'dark_mode': _isDarkMode,
          'step_history': prefs.getStringList('step_history') ?? [],
          'steps': prefs.getInt('steps') ?? 0,
        }
      };

      // Get save location from user
      final now = DateTime.now().toIso8601String().replaceAll(':', '-');
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup file',
        fileName: 'app_data_export_$now.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
      );

      if (outputFile == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export cancelled')),
        );
        return;
      }

      // Ensure file has .json extension
      if (!outputFile.toLowerCase().endsWith('.json')) {
        outputFile += '.json';
      }

      // Write data
      final file = File(outputFile);
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      await file.writeAsString(jsonString, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data exported to ${file.path}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.notifications_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('Notifications'),
                subtitle: const Text('Enable or disable notifications'),
                trailing: Switch.adaptive(
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.dark_mode_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('Dark Mode'),
                subtitle: const Text('Toggle dark theme'),
                trailing: Switch.adaptive(
                  value: _isDarkMode,
                  onChanged: _toggleDarkMode,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Data Management',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.upload_rounded,
                        color: theme.colorScheme.primary),
                    title: const Text('Import Data'),
                    subtitle: const Text('Import app data from backup'),
                    onTap: _importData,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.download_rounded,
                        color: theme.colorScheme.primary),
                    title: const Text('Export Data (JSON)'),
                    subtitle: const Text('Export all app data as JSON'),
                    onTap: _exportData,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.text_snippet_rounded,
                        color: theme.colorScheme.primary),
                    title: const Text('Export Data (Text)'),
                    subtitle:
                        const Text('Export all app data as readable text'),
                    onTap: _exportDataAsText,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'About',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.info_outline_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('About Developer'),
                subtitle: const Text('Learn more about the app developer'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
