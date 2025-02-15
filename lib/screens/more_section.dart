import 'package:flutter/material.dart';

import 'link.dart';
import 'steptracking.dart';
import 'youtube.dart';
import 'passwordsaver.dart';
import 'calculator.dart';

class ChatbotSection extends StatefulWidget {
  final Function(bool) toggleTheme;
  final ThemeMode themeMode;

  const ChatbotSection({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  @override
  State<ChatbotSection> createState() => _ChatbotSectionState();
}

class _ChatbotSectionState extends State<ChatbotSection> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot'),
      ),
      body: const Center(
        child: Text('Chatbot Coming Soon'),
      ),
    );
  }
}

class MoreSection extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final ThemeMode themeMode;

  const MoreSection({
    super.key,
    required this.onThemeChanged,
    required this.themeMode,
  });

  @override
  State<MoreSection> createState() => _MoreSectionState();
}

class _MoreSectionState extends State<MoreSection> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'More',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 24),
                _buildMenuItem(
                  context,
                  icon: Icons.directions_run,
                  title: 'Steps Tracking',
                  onTap: () =>
                      _navigateToScreen(context, const StepTrackingScreen()),
                ),
                const SizedBox(height: 16),
                _buildMenuItem(
                  context,
                  icon: Icons.link,
                  title: 'Links',
                  onTap: () => _navigateToScreen(context, const LinkScreen()),
                ),
                const SizedBox(height: 16),
                _buildMenuItem(
                  context,
                  icon: Icons.play_circle_outline,
                  title: 'YouTube Video Strategy',
                  onTap: () =>
                      _navigateToScreen(context, const YouTubeScreen()),
                ),
                const SizedBox(height: 16),
                _buildMenuItem(
                  context,
                  icon: Icons.chat_bubble_outline,
                  title: 'Chatbot',
                  onTap: () => _navigateToScreen(
                    context,
                    ChatbotSection(
                      toggleTheme: widget.onThemeChanged,
                      themeMode: widget.themeMode,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMenuItem(
                  context,
                  icon: Icons.lock_outline_rounded,
                  title: 'Password Saver',
                  onTap: () =>
                      _navigateToScreen(context, const PasswordSaver()),
                ),
                const SizedBox(height: 16),
                _buildMenuItem(
                  context,
                  icon: Icons.calculate_rounded,
                  title: 'Calculator',
                  onTap: () => _navigateToScreen(context, const Calculator()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToScreen(BuildContext context, Widget screen) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error navigating to screen: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
