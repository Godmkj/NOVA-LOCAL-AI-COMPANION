import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'screens/dashboard_screen.dart';
import 'screens/floating_orb_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize window acrylic blur styles
  await Window.initialize();
  await Window.setEffect(
    effect: WindowEffect.acrylic,
    color: Color(0x1F12121A), // Transparent dark tint
  );

  // Initialize window size and positions
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Frameless UI
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.setFocus(true);
  });

  runApp(
    const ProviderScope(
      child: NovaApp(),
    ),
  );
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOVA AI Companion',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFCC), // Glowing Cyan
          secondary: Color(0xFF8A2BE2), // Electric Purple
          background: Color(0x0A000000),
        ),
      ),
      initialRoute: '/dashboard',
      routes: {
        '/dashboard': (context) => const DashboardScreen(),
        '/orb': (context) => const FloatingOrbScreen(),
      },
    );
  }
}
