enum Priority { low, medium, high }

class Todo {
  String id;
  String title;
  bool isCompleted;
  DateTime createdAt;
  DateTime? notificationDate;
  Priority priority;
  String? category;

  Todo({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
    this.notificationDate,
    this.priority = Priority.medium,
    this.category,
  });

  void update({
    String? title,
    bool? isCompleted,
    DateTime? notificationDate,
    Priority? priority,
    String? category,
  }) {
    if (title != null) this.title = title;
    if (isCompleted != null) this.isCompleted = isCompleted;
    if (notificationDate != null) this.notificationDate = notificationDate;
    if (priority != null) this.priority = priority;
    if (category != null) this.category = category;
  }

  void toggleComplete() {
    isCompleted = !isCompleted;
  }

  void removeNotification() {
    notificationDate = null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'notificationDate': notificationDate?.toIso8601String(),
      'priority': priority.index,
      'category': category,
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      title: json['title'],
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      notificationDate: json['notificationDate'] != null
          ? DateTime.parse(json['notificationDate'])
          : null,
      priority: json['priority'] != null
          ? Priority.values[json['priority']]
          : Priority.medium,
      category: json['category'],
    );
  }

  bool isDueToday() {
    if (notificationDate == null) return false;
    final now = DateTime.now();
    return notificationDate!.year == now.year &&
        notificationDate!.month == now.month &&
        notificationDate!.day == now.day;
  }

  bool isOverdue() {
    if (notificationDate == null || isCompleted) return false;
    return notificationDate!.isBefore(DateTime.now());
  }
}
