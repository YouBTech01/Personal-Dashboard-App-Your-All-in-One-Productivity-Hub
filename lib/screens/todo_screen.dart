import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

extension ObjectExt<T> on T? {
  R? let<R>(R Function(T) block) => this == null ? null : block(this!);
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> with TickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final NotificationService _notificationService = NotificationService.instance;
  final _controller = TextEditingController();
  List<Todo> _todos = [];
  final List<String> _categories = ['All', 'Active', 'Completed'];
  String _selectedCategory = 'All';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedCategory = _categories[_tabController.index];
      });
    });
    _initializeNotifications();
    _loadTodos();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
  }

  Future<void> _loadTodos() async {
    final todos = await _storage.loadTodos();
    setState(() => _todos = todos);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<Todo> _getFilteredTodos() {
    return _todos.where((todo) {
      if (_selectedCategory == 'All') return true;
      if (_selectedCategory == 'Active') return !todo.isCompleted;
      return todo.isCompleted;
    }).toList();
  }

  Future<void> _handleNotificationError(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: _loadTodos,
          textColor: Theme.of(context).colorScheme.onError,
        ),
      ),
    );
  }

  Future<void> _addTodo() async {
    try {
      _controller.clear();
      DateTime? selectedDate;

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('New Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Task',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications),
                  title: Text(
                    selectedDate?.let((date) =>
                            DateFormat('MMM d, h:mm a').format(date)) ??
                        'Add Reminder',
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );

                    if (date != null && context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );

                      if (time != null) {
                        setState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (_controller.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Task cannot be empty')),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'title': _controller.text.trim(),
                    'reminder': selectedDate,
                  });
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );

      if (result != null) {
        final todo = Todo(
          id: DateTime.now().toString(),
          title: result['title'],
          createdAt: DateTime.now(),
          notificationDate: result['reminder'],
        );

        setState(() => _todos.add(todo));
        await _storage.saveTodos(_todos);

        if (todo.notificationDate != null) {
          try {
            await _notificationService.scheduleNotification(
              id: todo.id,
              title: 'Task Reminder',
              body: todo.title,
              scheduledDate: todo.notificationDate!,
              type: 'todo',
              uniqueId: todo.id,
            );
          } catch (e) {
            debugPrint('Error scheduling notification: $e');
            _handleNotificationError('Failed to set reminder. Task saved.');
          }
        }
      }
    } catch (e) {
      debugPrint('Error adding todo: $e');
      _handleNotificationError('Error adding task. Please try again.');
    }
  }

  Future<void> _toggleTodo(Todo todo) async {
    try {
      todo.toggleComplete();
      setState(() {});
      await _storage.saveTodos(_todos);

      if (todo.isCompleted && todo.notificationDate != null) {
        try {
          await _notificationService.cancelNotification(todo.id);
        } catch (e) {
          debugPrint('Error canceling notification: $e');
        }
      }
    } catch (e) {
      debugPrint('Error toggling todo: $e');
      _handleNotificationError('Error updating task. Please try again.');
    }
  }

  Future<void> _editTodo(Todo todo) async {
    try {
      _controller.text = todo.title;
      DateTime? selectedDate = todo.notificationDate;

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Edit Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Task',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications),
                  title: Text(
                    selectedDate?.let((date) =>
                            DateFormat('MMM d, h:mm a').format(date)) ??
                        'Add Reminder',
                  ),
                  trailing: selectedDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() => selectedDate = null);
                            todo.removeNotification();
                          },
                        )
                      : null,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );

                    if (date != null && context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(
                            selectedDate ?? DateTime.now()),
                      );

                      if (time != null) {
                        setState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (_controller.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Task cannot be empty')),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'title': _controller.text.trim(),
                    'reminder': selectedDate,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );

      if (result != null) {
        if (todo.notificationDate != null) {
          await _notificationService.cancelNotification(todo.id);
        }

        todo.update(
          title: result['title'],
          notificationDate: result['reminder'],
        );
        setState(() {});

        await _storage.saveTodos(_todos);

        if (todo.notificationDate != null) {
          try {
            await _notificationService.scheduleNotification(
              id: todo.id,
              title: 'Task Reminder',
              body: todo.title,
              scheduledDate: todo.notificationDate!,
              type: 'todo',
              uniqueId: todo.id,
            );
          } catch (e) {
            debugPrint('Error scheduling notification: $e');
            _handleNotificationError('Failed to set reminder. Task saved.');
          }
        }
      }
    } catch (e) {
      debugPrint('Error editing todo: $e');
      _handleNotificationError('Error updating task. Please try again.');
    }
  }

  Future<void> _deleteTodo(Todo todo) async {
    if (todo.notificationDate != null) {
      await _notificationService.cancelNotification(todo.id);
    }
    setState(() => _todos.remove(todo));
    await _storage.saveTodos(_todos);
  }

  @override
  Widget build(BuildContext context) {
    final filteredTodos = _getFilteredTodos();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tasks',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_todos.where((t) => !t.isCompleted).length} remaining',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary.withAlpha(179),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabController,
                    tabs: _categories
                        .map((category) => Tab(text: category))
                        .toList(),
                    labelColor: theme.colorScheme.onPrimary,
                    unselectedLabelColor:
                        theme.colorScheme.onPrimary.withAlpha(128),
                    indicatorColor: theme.colorScheme.onPrimary,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredTodos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 64,
                            color: theme.colorScheme.primary.withAlpha(128),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tasks found',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withAlpha(128),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: filteredTodos.length,
                      itemBuilder: (context, index) {
                        final todo = filteredTodos[index];
                        return Dismissible(
                          key: Key(todo.id),
                          background: Container(
                            color: theme.colorScheme.error,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: Icon(Icons.delete,
                                color: theme.colorScheme.onError),
                          ),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _deleteTodo(todo),
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              leading: Icon(
                                todo.isCompleted
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: todo.isCompleted
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface
                                        .withAlpha(128),
                              ),
                              onTap: () => _toggleTodo(todo),
                              onLongPress: () => _editTodo(todo),
                              title: Text(
                                todo.title,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              subtitle: todo.notificationDate != null
                                  ? Text(
                                      DateFormat('MMM d, h:mm a')
                                          .format(todo.notificationDate!),
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                      ),
                                    )
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editTodo(todo),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTodo,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }
}
