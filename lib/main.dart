import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'core/theme/app_theme.dart';
import 'providers/video_wall_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Global visibility detector update interval — reduces callback overhead
  VisibilityDetectorController.instance.updateInterval =
      const Duration(milliseconds: 200);

  // Lock to portrait for the wall; fullscreen unlocks landscape internally
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const MasonryVideoApp());
}

class MasonryVideoApp extends StatelessWidget {
  const MasonryVideoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideoWallProvider(),
      child: MaterialApp(
        title: 'High-Density Masonry Video Tiles',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
