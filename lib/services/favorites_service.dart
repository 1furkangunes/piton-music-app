import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/music.dart';

class FavoritesService {
  static const String _favoritesKey = 'favorite_musics';
  static const String _favoritesCountKey = 'favorites_count';

  // In-memory cache for performance
  static List<Music> _favoriteCache = [];
  static bool _isInitialized = false;

  // Initialize favorites from local storage
  static Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      if (kIsWeb) {
        // Web için localStorage simulation (gelecekte web storage eklenebilir)
        await _loadFromMemory();
      } else {
        // Mobile için SharedPreferences
        await _loadFromSharedPreferences();
      }
    } catch (e) {
      debugPrint('Error initializing favorites: $e');
      _favoriteCache = [];
    }

    _isInitialized = true;
  }

  // SharedPreferences'dan yükle (Mobile)
  static Future<void> _loadFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];

      _favoriteCache =
          favoritesJson.map((json) {
            final Map<String, dynamic> musicMap = jsonDecode(json);
            return Music.fromJson(musicMap);
          }).toList();

      debugPrint(
        'Loaded ${_favoriteCache.length} favorites from SharedPreferences',
      );
    } catch (e) {
      debugPrint('Error loading from SharedPreferences: $e');
      _favoriteCache = [];
    }
  }

  // SharedPreferences'a kaydet (Mobile)
  static Future<void> _saveToSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson =
          _favoriteCache.map((music) {
            return jsonEncode(music.toJson());
          }).toList();

      await prefs.setStringList(_favoritesKey, favoritesJson);
      await prefs.setInt(_favoritesCountKey, _favoriteCache.length);

      debugPrint(
        'Saved ${_favoriteCache.length} favorites to SharedPreferences',
      );
    } catch (e) {
      debugPrint('Error saving to SharedPreferences: $e');
    }
  }

  // Web için memory cache (geçici)
  static Future<void> _loadFromMemory() async {
    // Web'de session boyunca memory'de tutalım
    debugPrint('Using memory cache for web platform');
  }

  // Favori müzik ekle
  static Future<void> addToFavorites(Music music) async {
    await _initialize();

    // Duplicate kontrolü
    final exists = _favoriteCache.any((m) => m.id == music.id);
    if (!exists) {
      _favoriteCache.add(music);

      if (!kIsWeb) {
        await _saveToSharedPreferences();
      }

      debugPrint('Added to favorites: ${music.title}');
    }
  }

  // Favorilerden kaldır
  static Future<void> removeFromFavorites(String musicId) async {
    await _initialize();

    final initialLength = _favoriteCache.length;
    _favoriteCache.removeWhere((music) => music.id == musicId);

    if (_favoriteCache.length != initialLength) {
      if (!kIsWeb) {
        await _saveToSharedPreferences();
      }
      debugPrint('Removed from favorites: $musicId');
    }
  }

  // Favori olup olmadığını kontrol et
  static Future<bool> isFavorite(String musicId) async {
    await _initialize();
    return _favoriteCache.any((music) => music.id == musicId);
  }

  // Tüm favori müzikleri getir
  static Future<List<Music>> getFavorites() async {
    await _initialize();
    return List.from(_favoriteCache);
  }

  // Favori sayısını getir
  static Future<int> getFavoritesCount() async {
    await _initialize();
    return _favoriteCache.length;
  }

  // Tüm favorileri temizle
  static Future<void> clearAllFavorites() async {
    await _initialize();

    _favoriteCache.clear();

    if (!kIsWeb) {
      await _saveToSharedPreferences();
    }

    debugPrint('All favorites cleared');
  }

  // Cache'i temizle ve yeniden yükle
  static Future<void> reloadFavorites() async {
    _isInitialized = false;
    _favoriteCache.clear();
    await _initialize();
  }

  // Debug için cache durumunu göster
  static void printCacheStatus() {
    debugPrint('Favorites Cache: ${_favoriteCache.length} items');
    debugPrint('Initialized: $_isInitialized');
  }
}
