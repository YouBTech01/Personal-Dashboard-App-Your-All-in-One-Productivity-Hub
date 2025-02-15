import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';
import '../models/note.dart';

class StorageService {
  static const String _todoKey = 'todos';
  static const String _noteKey = 'notes';
  static const String _notificationSettingsKey = 'notification_settings';

  Future<void> saveTodos(List<Todo> todos) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedTodos = json.encode(
      todos.map((todo) => todo.toJson()).toList(),
    );
    await prefs.setString(_todoKey, encodedTodos);

    // Save notification settings for todos
    final notificationSettings = todos
        .where((todo) => todo.notificationDate != null)
        .map((todo) => {
              'id': todo.id,
              'notificationDate': todo.notificationDate!.toIso8601String(),
            })
        .toList();
    await prefs.setString(
        '${_notificationSettingsKey}_todos', json.encode(notificationSettings));
  }

  Future<List<Todo>> loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedTodos = prefs.getString(_todoKey);
    if (encodedTodos == null) return [];

    final List<dynamic> decodedTodos = json.decode(encodedTodos);
    return decodedTodos.map((todo) => Todo.fromJson(todo)).toList();
  }

  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedNotes = json.encode(
      notes.map((note) => note.toJson()).toList(),
    );
    await prefs.setString(_noteKey, encodedNotes);

    // Save notification settings for notes
    final notificationSettings = notes
        .where((note) => note.notificationDate != null)
        .map((note) => {
              'id': note.id,
              'notificationDate': note.notificationDate!.toIso8601String(),
            })
        .toList();
    await prefs.setString(
        '${_notificationSettingsKey}_notes', json.encode(notificationSettings));
  }

  Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedNotes = prefs.getString(_noteKey);
    if (encodedNotes == null) return [];

    final List<dynamic> decodedNotes = json.decode(encodedNotes);
    return decodedNotes.map((note) => Note.fromJson(note)).toList();
  }

  Future<List<Map<String, String>>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, String>> settings = [];

    // Load todo notifications
    final String? todoSettings =
        prefs.getString('${_notificationSettingsKey}_todos');
    if (todoSettings != null) {
      final List<dynamic> decoded = json.decode(todoSettings);
      settings.addAll(decoded.map((item) => Map<String, String>.from(item)));
    }

    // Load note notifications
    final String? noteSettings =
        prefs.getString('${_notificationSettingsKey}_notes');
    if (noteSettings != null) {
      final List<dynamic> decoded = json.decode(noteSettings);
      settings.addAll(decoded.map((item) => Map<String, String>.from(item)));
    }

    return settings;
  }

  Future<void> clearNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_notificationSettingsKey}_todos');
    await prefs.remove('${_notificationSettingsKey}_notes');
  }
}
