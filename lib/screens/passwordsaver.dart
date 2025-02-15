import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';

class PasswordEntry {
  final String platform;
  final String password;

  PasswordEntry({required this.platform, required this.password});

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'password': password,
      };

  factory PasswordEntry.fromJson(Map<String, dynamic> json) => PasswordEntry(
        platform: json['platform'],
        password: json['password'],
      );
}

class PasswordSaver extends StatefulWidget {
  const PasswordSaver({super.key});

  @override
  State<PasswordSaver> createState() => _PasswordSaverState();
}

class _PasswordSaverState extends State<PasswordSaver> {
  final storage = const FlutterSecureStorage();
  final localAuth = LocalAuthentication();
  final TextEditingController _platformController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final List<PasswordEntry> _passwords = [];
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _loadPasswords();
  }

  Future<void> _loadPasswords() async {
    try {
      final passwordsJson = await storage.read(key: 'passwords');
      if (passwordsJson != null) {
        setState(() {
          _passwords.addAll(
            (jsonDecode(passwordsJson) as List)
                .map((e) => PasswordEntry.fromJson(e)),
          );
        });
      }
    } on Exception catch (ex) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading passwords: $ex'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _savePassword() async {
    final platform = _platformController.text.trim();
    final password = _passwordController.text.trim();

    if (platform.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final newPassword = PasswordEntry(platform: platform, password: password);
    try {
      setState(() {
        _passwords.add(newPassword);
      });
      await _savePasswords();
      _platformController.clear();
      _passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving password: $e')),
      );
    }
  }

  Future<void> _savePasswords() async {
    final passwordsJson = _passwords.map((e) => e.toJson()).toList();
    await storage.write(key: 'passwords', value: jsonEncode(passwordsJson));
  }

  Future<void> _showPassword(PasswordEntry password) async {
    bool authenticated = false;
    try {
      setState(() => _isAuthenticating = true);

      final canAuthenticate = await localAuth.canCheckBiometrics;
      if (!canAuthenticate) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric auth unavailable')),
        );
        return;
      }

      authenticated = await localAuth.authenticate(
        localizedReason: 'Please authenticate to view password',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } on Exception catch (ex) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authentication error: $ex'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );

      return;
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }

    if (!authenticated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Authentication failed. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show password in a dialog
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_open_rounded,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(password.platform),
          ],
        ),
        content: SelectableText(
          password.password,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: password.password));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password copied to clipboard'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to copy: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    duration: Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: Icon(Icons.copy_rounded,
                color: Theme.of(context).colorScheme.primary),
            label: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePassword(PasswordEntry password) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_rounded,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            const Text('Delete Password'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the password for ${password.platform}? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        setState(() {
          _passwords.remove(password);
        });
        await _savePasswords();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password deleted')),
        );
      } on Exception catch (ex) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting password: $ex'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Saver'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPasswordDialog,
        child: const Icon(Icons.add),
      ),
      body: _isAuthenticating
          ? const Center(child: CircularProgressIndicator())
          : _passwords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 64,
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No passwords saved yet',
                        style: TextStyle(
                          fontSize: 18,
                          color:
                              theme.colorScheme.onBackground.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _passwords.length,
                  itemBuilder: (context, index) {
                    final password = _passwords[index];
                    return Dismissible(
                      key: Key(password.platform),
                      background: Container(
                        color: theme.colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: Icon(Icons.delete,
                            color: theme.colorScheme.onError),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _deletePassword(password),
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.lock_outline_rounded,
                              color: theme.colorScheme.primary),
                          title: Text(password.platform),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_red_eye_rounded),
                                tooltip: 'View Password',
                                onPressed: () => _showPassword(password),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded),
                                tooltip: 'Copy Password',
                                onPressed: () async {
                                  try {
                                    await Clipboard.setData(
                                        ClipboardData(text: password.password));
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Password copied'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to copy: $e'),
                                        backgroundColor:
                                            Theme.of(context).colorScheme.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _showAddPasswordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('Add Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _platformController,
              decoration: const InputDecoration(
                labelText: 'Platform',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.web),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
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
              _savePassword();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
