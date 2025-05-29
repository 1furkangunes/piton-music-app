import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class ThemeService {
  static const String _themeKey = 'is_dark_mode';

  static bool _isDarkMode = true; // Varsayılan dark mode
  static bool _isInitialized = false;

  // Stream controller for theme changes
  static final StreamController<bool> _themeController =
      StreamController<bool>.broadcast();

  // Initialize theme from local storage
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (kIsWeb) {
        // Web için localStorage simulation
        _isDarkMode = true; // Varsayılan dark
        debugPrint('Using memory cache for web theme');
      } else {
        // Mobile için SharedPreferences
        await _loadFromSharedPreferences();
      }
    } catch (e) {
      debugPrint('Error initializing theme: $e');
      _isDarkMode = true;
    }

    _isInitialized = true;
    debugPrint('Theme initialized: ${_isDarkMode ? 'Dark' : 'Light'}');
  }

  // SharedPreferences'dan tema yükle
  static Future<void> _loadFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? true; // Varsayılan dark mode
      debugPrint(
        'Loaded theme from SharedPreferences: ${_isDarkMode ? 'Dark' : 'Light'}',
      );
    } catch (e) {
      debugPrint('Error loading theme from SharedPreferences: $e');
      _isDarkMode = true;
    }
  }

  // SharedPreferences'a tema kaydet
  static Future<void> _saveToSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
      debugPrint(
        'Saved theme to SharedPreferences: ${_isDarkMode ? 'Dark' : 'Light'}',
      );
    } catch (e) {
      debugPrint('Error saving theme to SharedPreferences: $e');
    }
  }

  // Get current theme mode
  static bool get isDarkMode => _isDarkMode;

  // Toggle theme
  static Future<void> toggleTheme() async {
    await initialize();
    _isDarkMode = !_isDarkMode;

    // Save to local storage
    if (!kIsWeb) {
      await _saveToSharedPreferences();
    }

    // Notify listeners
    _themeController.add(_isDarkMode);

    debugPrint('Theme toggled to: ${_isDarkMode ? 'Dark' : 'Light'}');
  }

  // Set theme explicitly
  static Future<void> setTheme(bool isDark) async {
    await initialize();

    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;

      // Save to local storage
      if (!kIsWeb) {
        await _saveToSharedPreferences();
      }

      // Notify listeners
      _themeController.add(_isDarkMode);

      debugPrint('Theme set to: ${_isDarkMode ? 'Dark' : 'Light'}');
    }
  }

  // Get theme data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: Colors.deepPurple,
      primaryColor: const Color(0xFF6C5CE7),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF6C5CE7),
        secondary: Color(0xFF00B4D8),
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.black,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: Colors.deepPurple,
      primaryColor: const Color(0xFF6C5CE7),
      scaffoldBackgroundColor: const Color(0xFF1C1B33),
      cardColor: const Color(0xFF2A2A4A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1C1B33),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6C5CE7),
        secondary: Color(0xFF00B4D8),
        surface: Color(0xFF2A2A4A),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
    );
  }

  // Get current theme
  static ThemeData get currentTheme {
    return _isDarkMode ? darkTheme : lightTheme;
  }

  // Theme colors for manual usage
  static Color get backgroundColor {
    return _isDarkMode ? const Color(0xFF1C1B33) : const Color(0xFFF5F5F5);
  }

  static Color get cardColor {
    return _isDarkMode ? const Color(0xFF2A2A4A) : Colors.white;
  }

  static Color get textColor {
    return _isDarkMode ? Colors.white : Colors.black;
  }

  static Color get subtitleColor {
    return _isDarkMode ? Colors.grey : Colors.grey.shade600;
  }

  static Color get primaryColor => const Color(0xFF6C5CE7);
  static Color get secondaryColor => const Color(0xFF00B4D8);

  // Stream for theme changes
  static Stream<bool> get themeStream => _themeController.stream;

  // Debug için tema durumunu göster
  static void printThemeStatus() {
    debugPrint('Current Theme: ${_isDarkMode ? 'Dark' : 'Light'}');
    debugPrint('Initialized: $_isInitialized');
  }

  // Reload theme from storage
  static Future<void> reloadTheme() async {
    _isInitialized = false;
    await initialize();
  }

  // Dispose method
  static void dispose() {
    _themeController.close();
  }
}
