import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/getting_started_screen.dart';
import 'screens/downloads_screen.dart';
import 'services/audio_player_service.dart';
import 'services/download_service.dart';
import 'services/theme_service.dart';
import 'services/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (!details.toString().contains('overflow')) {
        FlutterError.presentError(details);
      }
    };
  }

  // Modern tam ekran görünüm - Navigation bar gizli
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Status bar ve navigation bar şeffaf
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await AudioPlayerService.initialize();
  await DownloadService.initialize();
  await ThemeService.initialize();
  await ConnectivityService.initialize();
  runApp(const MusicApp());
}

class MusicApp extends StatefulWidget {
  const MusicApp({super.key});

  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ThemeService.themeStream,
      initialData: ThemeService.isDarkMode,
      builder: (context, snapshot) {
        return MaterialApp(
          title: 'PitonMusic',
          debugShowCheckedModeBanner: false,
          theme: ThemeService.lightTheme.copyWith(
            textTheme: GoogleFonts.poppinsTextTheme().apply(
              bodyColor: Colors.black,
              displayColor: Colors.black,
            ),
          ),
          darkTheme: ThemeService.darkTheme.copyWith(
            textTheme: GoogleFonts.poppinsTextTheme().apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
          ),
          themeMode: ThemeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
          routes: {
            '/getting-started': (context) => const GettingStartedScreen(),
            '/downloads': (context) => const DownloadsScreen(),
          },
        );
      },
    );
  }
}
