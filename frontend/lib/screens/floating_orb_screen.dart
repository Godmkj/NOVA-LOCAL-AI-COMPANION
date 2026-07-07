import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';

class FloatingOrbScreen extends StatefulWidget {
  const FloatingOrbScreen({super.key});

  @override
  State<FloatingOrbScreen> createState() => _FloatingOrbScreenState();
}

class _FloatingOrbScreenState extends State<FloatingOrbScreen> with SingleTickerProviderStateMixin {
  late AnimationController _orbController;

  @override
  void initState() {
    super.initState();
    // Shrink window size to suit mini floating mode
    _configureMiniWindow();
    
    // Set up breathing animation for the orb
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _configureMiniWindow() async {
    await windowManager.setSize(const Size(200, 200));
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setResizable(false);
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging(); // Allows dragging window by holding orb
      },
      onDoubleTap: () async {
        // Double tap restores dashboard window size
        await windowManager.setResizable(true);
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setSize(const Size(1280, 800));
        await windowManager.center();
        Navigator.pushReplacementNamed(context, '/dashboard');
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating animated glow circles
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  return Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FFCC).withOpacity(0.3 * _orbController.value),
                          blurRadius: 20 + (15 * _orbController.value),
                          spreadRadius: 2 + (8 * _orbController.value),
                        ),
                        BoxShadow(
                          color: const Color(0xFF8A2BE2).withOpacity(0.2 * (1.0 - _orbController.value)),
                          blurRadius: 25,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              // Central Orb body
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xEE0F0C20),
                      Color(0xDD00FFCC),
                    ],
                    center: Alignment(-0.2, -0.3),
                    radius: 0.8,
                  ),
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: const Icon(
                  LucideIcons.mic, 
                  color: Colors.white, 
                  size: 28
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
