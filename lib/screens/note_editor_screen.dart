import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  Future<void> _handleNotificationError(
      BuildContext context, String message) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  final _headlineController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _reminderDate;
  String _selectedCategory = 'Personal';
  Color _selectedColor = Colors.blue;
  bool _isPinned = false;

  final List<String> _categories = [
    'Personal',
    'Work',
    'Shopping',
    'Ideas',
    'Tasks',
    'Other'
  ];

  final List<Color> _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _headlineController.text = widget.note!.headline;
      _descriptionController.text = widget.note!.description;
      _reminderDate = widget.note!.notificationDate;
      _selectedCategory = widget.note!.category;
      _selectedColor = widget.note!.color;
      _isPinned = widget.note!.isPinned;
    }
  }

  @override
  void dispose() {
    _headlineController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<DateTime?> _showDateTimePicker() async {
    try {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

      if (date == null || !mounted) return null;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time == null) return null;

      return DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error setting reminder: $e')),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
        actions: [
          IconButton(
            icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: () => setState(() => _isPinned = !_isPinned),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (_headlineController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a title')),
                );
                return;
              }

              final note = Note(
                id: widget.note?.id ?? DateTime.now().toString(),
                headline: _headlineController.text.trim(),
                description: _descriptionController.text.trim(),
                createdAt: widget.note?.createdAt ?? DateTime.now(),
                notificationDate: _reminderDate,
                category: _selectedCategory,
                color: _selectedColor,
                isPinned: _isPinned,
              );

              if (_reminderDate != null &&
                  _reminderDate!.isBefore(DateTime.now())) {
                _handleNotificationError(
                    context, 'Cannot set reminder for past date');
                return;
              }

              Navigator.pop(context, note);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _headlineController,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: _categories.map((category) {
                return ChoiceChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = category);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: _colors.map((color) {
                return InkWell(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _selectedColor == color
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Note content...',
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.notifications),
              label: Text(_reminderDate == null
                  ? 'Add Reminder'
                  : DateFormat('MMM d, h:mm a').format(_reminderDate!)),
              onPressed: () async {
                final date = await _showDateTimePicker();
                if (date != null) setState(() => _reminderDate = date);
              },
            ),
          ],
        ),
      ),
    );
  }
}
