import 'package:flutter/material.dart';

class Note {
  String id;
  String headline;
  String description;
  DateTime createdAt;
  DateTime? notificationDate;
  String category;
  Color color;
  bool isPinned;

  Note({
    required this.id,
    required this.headline,
    required this.description,
    required this.createdAt,
    this.notificationDate,
    this.category = 'Personal',
    this.color = Colors.blue,
    this.isPinned = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'headline': headline,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'notificationDate': notificationDate?.toIso8601String(),
      'category': category,
      'color': color.value,
      'isPinned': isPinned,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      headline: json['headline'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      notificationDate: json['notificationDate'] != null
          ? DateTime.parse(json['notificationDate'])
          : null,
      category: json['category'] ?? 'Personal',
      color: Color(json['color'] ?? Colors.blue.value),
      isPinned: json['isPinned'] ?? false,
    );
  }
}
