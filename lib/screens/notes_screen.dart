import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/storage_service.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final StorageService _storage = StorageService();
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await _storage.loadNotes();
    setState(() => _notes = notes);
  }

  Future<void> _addNote() async {
    final note = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (context) => const NoteEditorScreen()),
    );

    if (note != null && mounted) {
      setState(() => _notes.add(note));
      await _storage.saveNotes(_notes);
    }
  }

  Future<void> _editNote(Note note) async {
    final editedNote = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (context) => NoteEditorScreen(note: note)),
    );

    if (editedNote != null && mounted) {
      setState(() {
        final index = _notes.indexWhere((n) => n.id == editedNote.id);
        if (index != -1) {
          _notes[index] = editedNote;
        }
      });
      await _storage.saveNotes(_notes);
    }
  }

  List<Note> _getSortedNotes() {
    final pinnedNotes = _notes.where((note) => note.isPinned).toList();
    final unpinnedNotes = _notes.where((note) => !note.isPinned).toList();
    return [...pinnedNotes, ...unpinnedNotes];
  }

  @override
  Widget build(BuildContext context) {
    final sortedNotes = _getSortedNotes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        centerTitle: true,
      ),
      body: sortedNotes.isEmpty
          ? const Center(child: Text('Add your first note!'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: sortedNotes.length,
              itemBuilder: (context, index) {
                final note = sortedNotes[index];
                return Card(
                  color: note.color.withOpacity(0.1),
                  child: ListTile(
                    leading: note.isPinned
                        ? const Icon(Icons.push_pin, size: 20)
                        : null,
                    title: Text(
                      note.headline,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: note.description.isNotEmpty
                        ? Text(note.description)
                        : null,
                    trailing: note.notificationDate != null
                        ? const Icon(Icons.notifications, size: 20)
                        : null,
                    onTap: () => _editNote(note),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}
