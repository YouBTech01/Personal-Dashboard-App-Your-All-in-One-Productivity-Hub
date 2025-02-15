import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

// ShimmerText widget for animated text effects
class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const ShimmerText(this.text, {super.key, this.style});

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
              Theme.of(context).colorScheme.primary,
            ],
            stops: const [0.0, 0.5, 1.0],
            transform: GradientRotation(_controller.value * 2 * math.pi),
          ).createShader(bounds),
          child: Text(
            widget.text,
            style: widget.style?.copyWith(color: Colors.white) ??
                const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  final double _profileSize = 180.0;
  double _dragX = 0.0;
  double _dragY = 0.0;
  int _tapCount = 0;

  void _showSecretMessage(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) => Transform.scale(
          scale: value,
          child: AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Colors.red.shade300,
                          Colors.red.shade700,
                          Colors.red.shade300,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                        transform: GradientRotation(value * 2 * math.pi),
                      ).createShader(bounds),
                      child: Icon(
                        Icons.favorite,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '🌟 Special Message for My Amazing Subscribers! 🌟',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Thank you for being part of this incredible tech journey! Your support and enthusiasm inspire me to create better content every day. Keep coding, keep learning, and together we\'ll achieve amazing things! 💻✨',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  '#YouBTechFamily 🚀',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _tapCount = 0;
  }

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Start intro animations
    Future.delayed(const Duration(milliseconds: 100), () {
      _scaleController.forward();
      _slideController.forward();
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    if (!mounted) return;

    if (!await launchUrl(Uri.parse(url))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge(
            [_scaleController, _slideController, _fadeController]),
        builder: (context, child) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 350,
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topLeft,
                        radius: 1.5,
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.surface,
                        ],
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 50,
                          child: Transform.scale(
                            scale: _scaleController.value,
                            child: AnimatedBuilder(
                              animation: _rotationController,
                              builder: (_, child) {
                                return Transform.rotate(
                                  angle:
                                      _rotationController.value * 2 * math.pi,
                                  child: Container(
                                    width: _profileSize + 40,
                                    height: _profileSize + 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: SweepGradient(
                                        colors: [
                                          Colors.blue.withAlpha(51),
                                          Colors.purple.withAlpha(51),
                                          Colors.red.withAlpha(51),
                                          Colors.blue.withAlpha(51),
                                        ],
                                        stops: const [0.0, 0.25, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          top: 100,
                          child: Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateX(_dragY * 0.01)
                              ..rotateY(_dragX * 0.01),
                            alignment: FractionalOffset.center,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _tapCount++;
                                  if (_tapCount == 3) {
                                    _showSecretMessage(context);
                                  }
                                });
                              },
                              onPanUpdate: (details) {
                                setState(() {
                                  _dragX += details.delta.dx;
                                  _dragY += details.delta.dy;
                                });
                              },
                              onPanEnd: (details) {
                                setState(() {
                                  _dragX = 0;
                                  _dragY = 0;
                                });
                              },
                              child: Transform.scale(
                                scale: _scaleController.value,
                                child: Hero(
                                  tag: 'profile',
                                  child: Container(
                                    width: _profileSize,
                                    height: _profileSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(51),
                                          blurRadius: 12,
                                          spreadRadius: 4,
                                        )
                                      ],
                                      image: const DecorationImage(
                                        image: AssetImage('assets/profile.jpg'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: Offset(0, 50 * (1 - _slideController.value)),
                    child: Opacity(
                      opacity: _fadeController.value,
                      child: Column(
                        children: [
                          _buildProfileInfo(context),
                          const SizedBox(height: 32),
                          _buildSocialGrid(context),
                          const SizedBox(height: 24),
                          _buildFooter(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileInfo(BuildContext context) {
    return Column(
      children: [
        Transform.scale(
          scale: _scaleController.value,
          child: ShimmerText(
            'Brajendra',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const SizedBox(height: 12),
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _slideController,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: _fadeController,
            child: Text(
              '18-year-old art student & tech enthusiast',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(204),
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 24),
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _slideController,
            curve: Curves.easeOutCubic,
          )),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Text(
              'This app helps you organize tasks, track fitness, '
              'and plan YouTube content—all in one place! ✨',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialGrid(BuildContext context) {
    return Column(
      children: [
        Transform.scale(
          scale: _scaleController.value,
          child: ShimmerText(
            'Connect With Me',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 4 : 3;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.8,
              children: _buildSocialCards(context),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildSocialCards(BuildContext context) {
    final List<Map<String, dynamic>> socialLinks = [
      {
        'icon': Icons.public,
        'label': 'Portfolio',
        'url': 'https://youbtech01.github.io/My-Portfolio-/',
        'color': Colors.blue,
      },
      {
        'icon': Icons.play_circle_filled,
        'label': 'YouTube',
        'url': 'https://youtube.com/@You_B_Tech',
        'color': Colors.red,
      },
      {
        'icon': Icons.forum,
        'label': 'Telegram',
        'url': 'https://t.me/You_B_Tech',
        'color': Colors.blueAccent,
      },
      {
        'icon': Icons.camera_alt,
        'label': 'Instagram',
        'url': 'https://instagram.com/you_b_tech',
        'color': Colors.purple,
      },
      {
        'icon': Icons.code,
        'label': 'Coding',
        'url': 'https://t.me/You_B_Tech_Coding',
        'color': Colors.green,
      },
      {
        'icon': Icons.language,
        'label': 'Website',
        'url': 'https://youbtech.xyz',
        'color': Colors.orange,
      },
    ];

    return List.generate(
      socialLinks.length,
      (index) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _slideController,
          curve: Interval(
            0.2 + (index * 0.1),
            1.0,
            curve: Curves.easeOutCubic,
          ),
        )),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _fadeController,
            curve: Interval(
              0.2 + (index * 0.1),
              1.0,
              curve: Curves.easeOut,
            ),
          ),
          child: _buildSocialCard(
            context,
            socialLinks[index]['icon'] as IconData,
            socialLinks[index]['label'] as String,
            socialLinks[index]['url'] as String,
            socialLinks[index]['color'] as Color,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialCard(
    BuildContext context,
    IconData icon,
    String label,
    String url,
    Color color,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        builder: (context, value, child) => Transform.scale(
          scale: value,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              onTap: () => _launchURL(url),
              borderRadius: BorderRadius.circular(20),
              splashColor: color.withAlpha(51),
              highlightColor: color.withAlpha(26),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withAlpha(38),
                      color.withAlpha(13),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 42,
                      color: color,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: Opacity(
        opacity: 0.6,
        child: Text(
          'Made with ❤️ using Flutter',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

// ShimmerText widget remains the same as in original code
