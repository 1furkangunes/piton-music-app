import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/theme_service.dart';
import 'getting_started_screen.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Fade animasyonu
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Animasyonu başlat
    _fadeController.forward();

    // 4 saniye sonra ana ekrana geç
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) =>
                    const GettingStartedScreen(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeService.backgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottie Animasyonu
              Lottie.asset(
                'assets/animations/starting.json',
                width: 250,
                height: 250,
                fit: BoxFit.contain,
                repeat: true,
                animate: true,
              ),

              const SizedBox(height: 40),

              // Uygulama Adı
              Text(
                'PitonMusic',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: ThemeService.textColor,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 16),

              // Alt yazı
              Text(
                'Müziğin Gücünü Keşfet',
                style: TextStyle(
                  fontSize: 16,
                  color: ThemeService.subtitleColor,
                  fontWeight: FontWeight.w300,
                ),
              ),

              const SizedBox(height: 60),

              // Loading indicator
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                  color: const Color(0xFF6C5CE7),
                  backgroundColor: ThemeService.subtitleColor.withValues(
                    alpha: 0.2,
                  ),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
