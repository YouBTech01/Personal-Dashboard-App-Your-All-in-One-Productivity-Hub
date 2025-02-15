import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LinkScreen extends StatefulWidget {
  const LinkScreen({super.key});

  @override
  State<LinkScreen> createState() => _LinkScreenState();
}

class _LinkScreenState extends State<LinkScreen> {
  // Add URL validation regex
  static final _urlRegex = RegExp(
    r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
    caseSensitive: false,
  );

  final Map<String, String> _links = {};
  final Map<String, IconData> _platformIcons = {
    'YouTube': Icons.play_circle_outline,
    'Instagram': Icons.camera_alt,
    'Telegram': Icons.send,
    'GitHub': Icons.code,
  };
  final Map<String, IconData> _availableIcons = {
    'Link': Icons.link,
    'Video': Icons.play_circle_outline,
    'Social': Icons.people,
    'Code': Icons.code,
    'Website': Icons.language,
    'Email': Icons.email,
    'Phone': Icons.phone,
    'Location': Icons.location_on,
  };
  final List<String> _platforms = [
    'YouTube',
    'Instagram',
    'Telegram',
    'GitHub',
  ];
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _selectedIconKey = 'Link';

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final platformsJson = prefs.getStringList('platforms') ?? _platforms;
      if (!mounted) return;
      setState(() {
        _platforms.clear();
        _platforms.addAll(platformsJson);
        for (final platform in _platforms) {
          _links[platform] = prefs.getString('link_$platform') ?? '';
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading links: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _savePlatforms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('platforms', _platforms);
  }

  @override
  void dispose() {
    _linkController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Validate URL
  bool _isValidUrl(String url) {
    return url.isEmpty || _urlRegex.hasMatch(url);
  }

  Future<void> _saveLink(String platform, String link) async {
    if (!_isValidUrl(link)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid URL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving link...')),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('link_$platform', link);
      await _savePlatforms();
      if (!mounted) return;
      setState(() {
        _links[platform] = link;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$platform link saved'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving link: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _editLink(String platform) async {
    try {
      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Editing link...')),
      );
      final controller = TextEditingController(text: _links[platform]);
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Edit $platform Link'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: '$platform URL',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.link),
              errorText:
                  controller.text.isNotEmpty && !_isValidUrl(controller.text)
                      ? 'Please enter a valid URL'
                      : null,
            ),
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (!_isValidUrl(controller.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid URL'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (result != null && mounted) {
        await _saveLink(platform, result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$platform link updated'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error editing link: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _addNewLink() async {
    _selectedIconKey = 'Link';
    _nameController.clear();
    _linkController.clear();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Link'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Link Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    labelText: 'URL',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.link),
                    errorText: _linkController.text.isNotEmpty &&
                            !_isValidUrl(_linkController.text)
                        ? 'Please enter a valid URL'
                        : null,
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                const Text('Select Icon'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableIcons.entries.map((entry) {
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedIconKey = entry.key);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _selectedIconKey == entry.key
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(entry.value),
                            const SizedBox(height: 4),
                            Text(entry.key,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_nameController.text.isEmpty ||
                    _linkController.text.isEmpty ||
                    !_isValidUrl(_linkController.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all fields correctly'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'name': _nameController.text.trim(),
                  'link': _linkController.text.trim(),
                  'icon': _selectedIconKey,
                });
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      try {
        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adding link...')),
        );
        setState(() {
          _platforms.add(result['name']!);
          _links[result['name']!] = result['link']!;
          _platformIcons[result['name']!] = _availableIcons[result['icon']!]!;
        });
        await _saveLink(result['name']!, result['link']!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['name']} link added'),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding link: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _copyLink(String platform) {
    try {
      final link = _links[platform];
      if (link != null && link.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: link));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$platform link copied to clipboard'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error copying link: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Media Links'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewLink,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Link'),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      body: _platforms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.link_off_rounded,
                    size: 64,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No links added yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.colorScheme.onBackground.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _platforms.length,
              itemBuilder: (context, index) {
                final platform = _platforms[index];
                final link = _links[platform] ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: _getPlatformIcon(platform),
                    title: Text(
                      platform,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      link.isEmpty ? 'No link added' : link,
                      style: TextStyle(
                        color:
                            theme.colorScheme.onPrimaryContainer.withAlpha(179),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (link.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              Icons.copy_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            onPressed: () => _copyLink(platform),
                            tooltip: 'Copy link',
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.edit_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          onPressed: () => _editLink(platform),
                          tooltip: 'Edit link',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () => _deletePlatform(platform),
                          tooltip: 'Delete platform',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _deletePlatform(String platform) async {
    try {
      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleting platform...')),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('link_$platform');
      if (!mounted) return;
      setState(() {
        _platforms.remove(platform);
        _links.remove(platform);
        _platformIcons.remove(platform);
      });
      await _savePlatforms();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$platform removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              setState(() {
                _platforms.add(platform);
                _platformIcons[platform] = Icons.link;
              });
              await _savePlatforms();
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing $platform: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _getPlatformIcon(String platform) {
    return Icon(
      _platformIcons[platform] ?? Icons.link,
      color: Theme.of(context).colorScheme.onPrimaryContainer,
      size: 28,
    );
  }
}
