import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class YouTubeScreen extends StatefulWidget {
  const YouTubeScreen({super.key});

  @override
  State<YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends State<YouTubeScreen>
    with TickerProviderStateMixin {
  final List<VideoStrategy> _strategies = [];
  final NotificationService _notificationService = NotificationService.instance;
  late AnimationController _animationController;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'date';
  bool _isDarkMode = false;
  final List<String> _categories = [
    'All',
    'Tutorial',
    'Vlog',
    'Review',
    'Other'
  ];

  List<VideoStrategy> get _sortedStrategies {
    final sorted = List<VideoStrategy>.from(_filteredStrategies);
    switch (_sortBy) {
      case 'date':
        sorted.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        break;
      case 'priority':
        sorted.sort((a, b) => b.priority.compareTo(a.priority));
        break;
      case 'title':
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
    }
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _loadStrategies();
    _loadTheme();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('dark_mode', _isDarkMode);
  }

  List<VideoStrategy> get _filteredStrategies {
    return _strategies.where((strategy) {
      final matchesSearch =
          strategy.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              strategy.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'All' || strategy.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _loadStrategies() async {
    final prefs = await SharedPreferences.getInstance();
    final strategiesJson = prefs.getStringList('video_strategies') ?? [];
    setState(() {
      _strategies.clear();
      _strategies.addAll(
        strategiesJson.map((json) => VideoStrategy.fromJson(json)),
      );
    });
  }

  Future<void> _saveStrategies() async {
    final prefs = await SharedPreferences.getInstance();
    final strategiesJson = _strategies.map((s) => s.toJson()).toList();
    await prefs.setStringList('video_strategies', strategiesJson);
  }

  Future<void> _addStrategy() async {
    if (!mounted) return;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'Tutorial';
    int selectedPriority = 1;
    late BuildContext dialogContext;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        dialogContext = context;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Video Strategy'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Video Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _categories.skip(1).map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: selectedPriority.toDouble(),
                      min: 1,
                      max: 3,
                      divisions: 2,
                      label: 'Priority: ${selectedPriority}',
                      onChanged: (value) {
                        setState(() {
                          selectedPriority = value.round();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: dialogContext,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          if (!mounted) return;
                          final time = await showTimePicker(
                            context: dialogContext,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null && mounted) {
                            final dateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                            Navigator.pop(dialogContext, {
                              'title': titleController.text,
                              'description': descriptionController.text,
                              'dateTime': dateTime,
                              'category': selectedCategory,
                              'priority': selectedPriority,
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Set Date & Time'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (result != null) {
      final strategy = VideoStrategy(
        title: result['title'],
        description: result['description'],
        dateTime: result['dateTime'],
        category: result['category'],
        priority: result['priority'],
      );

      try {
        setState(() {
          _strategies.add(strategy);
        });
        await _saveStrategies();

        if (!mounted) return;

        await _notificationService.scheduleNotification(
          id: strategy.id,
          title: 'YouTube Video Reminder',
          body: 'Time to create: ${strategy.title}',
          scheduledDate: strategy.dateTime,
          type: 'youtube',
          uniqueId: strategy.id,
        );
      } catch (e) {
        debugPrint('Error adding YouTube strategy notification: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to schedule notification'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteStrategy(VideoStrategy strategy) async {
    setState(() {
      _strategies.remove(strategy);
    });
    await _saveStrategies();
    await _notificationService.cancelNotification(strategy.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('YouTube Strategy'),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              onSelected: (value) {
                setState(() {
                  _sortBy = value;
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'date',
                  child: Text('Sort by Date'),
                ),
                const PopupMenuItem(
                  value: 'priority',
                  child: Text('Sort by Priority'),
                ),
                const PopupMenuItem(
                  value: 'title',
                  child: Text('Sort by Title'),
                ),
              ],
            ),
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: _toggleTheme,
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchAndFilter(theme),
            Expanded(
              child: AnimationLimiter(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sortedStrategies.length,
                  itemBuilder: (context, index) {
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: _buildStrategyCard(
                              _sortedStrategies[index], theme),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addStrategy,
          icon: const Icon(Icons.add),
          label: const Text('Add Strategy'),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search strategies...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _selectedCategory == category,
                    label: Text(category),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    backgroundColor: theme.colorScheme.surface,
                    selectedColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: _selectedCategory == category
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyCard(VideoStrategy strategy, ThemeData theme) {
    final priorityColors = [Colors.green, Colors.orange, Colors.red];
    final isUpcoming = strategy.dateTime.isAfter(DateTime.now());

    return Hero(
      tag: 'strategy-${strategy.id}',
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: InkWell(
          onTap: () => _showStrategyDetails(strategy),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: priorityColors[strategy.priority - 1].withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strategy.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                isUpcoming
                                    ? Icons.upcoming
                                    : Icons.check_circle,
                                size: 16,
                                color:
                                    isUpcoming ? Colors.orange : Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isUpcoming ? 'Upcoming' : 'Past',
                                style: TextStyle(
                                  color:
                                      isUpcoming ? Colors.orange : Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(strategy.category),
                      backgroundColor: theme.colorScheme.primaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  strategy.description,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, h:mm a').format(strategy.dateTime),
                      style: TextStyle(
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editStrategy(strategy),
                      color: theme.colorScheme.primary,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () => _deleteStrategy(strategy),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editStrategy(VideoStrategy strategy) async {
    if (!mounted) return;

    final titleController = TextEditingController(text: strategy.title);
    final descriptionController =
        TextEditingController(text: strategy.description);
    String selectedCategory = strategy.category;
    int selectedPriority = strategy.priority;
    DateTime selectedDateTime = strategy.dateTime;
    late BuildContext dialogContext;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        dialogContext = context;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Video Strategy'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Video Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _categories.skip(1).map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: selectedPriority.toDouble(),
                      min: 1,
                      max: 3,
                      divisions: 2,
                      label: 'Priority: ${selectedPriority}',
                      onChanged: (value) {
                        setState(() {
                          selectedPriority = value.round();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.calendar_today),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, h:mm a').format(selectedDateTime),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDateTime,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          if (!mounted) return;
                          final time = await showTimePicker(
                            context: dialogContext,
                            initialTime:
                                TimeOfDay.fromDateTime(selectedDateTime),
                          );
                          if (time != null && mounted) {
                            setState(() {
                              selectedDateTime = DateTime(
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
                      child: const Text('Change Date & Time'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, {
                      'title': titleController.text,
                      'description': descriptionController.text,
                      'dateTime': selectedDateTime,
                      'category': selectedCategory,
                      'priority': selectedPriority,
                    });
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (result != null) {
      final updatedStrategy = VideoStrategy(
        id: strategy.id,
        title: result['title'],
        description: result['description'],
        dateTime: result['dateTime'],
        category: result['category'],
        priority: result['priority'],
      );

      try {
        final index = _strategies.indexWhere((s) => s.id == strategy.id);
        if (index != -1) {
          setState(() {
            _strategies[index] = updatedStrategy;
          });
          await _saveStrategies();

          await _notificationService.cancelNotification(strategy.id);
          await _notificationService.scheduleNotification(
            id: updatedStrategy.id,
            title: 'YouTube Video Reminder',
            body: 'Time to create: ${updatedStrategy.title}',
            scheduledDate: updatedStrategy.dateTime,
            type: 'youtube',
            uniqueId: updatedStrategy.id,
          );
        }
      } catch (e) {
        debugPrint('Error updating YouTube strategy: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update strategy'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showStrategyDetails(VideoStrategy strategy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      strategy.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strategy.description,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(
                        Icons.category, 'Category', strategy.category),
                    _buildDetailRow(
                      Icons.priority_high,
                      'Priority',
                      'Level ${strategy.priority}',
                    ),
                    _buildDetailRow(
                      Icons.access_time,
                      'Scheduled for',
                      DateFormat('MMM d, yyyy h:mm a')
                          .format(strategy.dateTime),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }
}

class VideoStrategy {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final String category;
  final int priority;

  VideoStrategy({
    String? id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.category,
    required this.priority,
  }) : id = id ?? DateTime.now().toString();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'category': category,
      'priority': priority,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory VideoStrategy.fromMap(Map<String, dynamic> map) {
    return VideoStrategy(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      dateTime: DateTime.parse(map['dateTime']),
      category: map['category'] ?? 'Other',
      priority: map['priority'] ?? 1,
    );
  }

  factory VideoStrategy.fromJson(String json) =>
      VideoStrategy.fromMap(jsonDecode(json));
}
