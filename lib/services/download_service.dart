import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/music.dart';
import 'dart:convert';
import 'connectivity_service.dart';

class DownloadService {
  static final Dio _dio = Dio();
  static const String _downloadListKey = 'downloaded_musics';

  // Download progress stream
  static final StreamController<Map<String, double>> _progressController =
      StreamController<Map<String, double>>.broadcast();

  static Stream<Map<String, double>> get downloadProgressStream =>
      _progressController.stream;

  // Download durumunu takip etmek için
  static final Map<String, CancelToken> _activeDownloads = {};

  static Future<void> initialize() async {
    // Dio timeout ayarları - müzik dosyaları için daha uzun timeout
    _dio.options.connectTimeout = const Duration(seconds: 60); // 60 saniye
    _dio.options.receiveTimeout = const Duration(minutes: 10); // 10 dakika
    _dio.options.sendTimeout = const Duration(minutes: 10); // 10 dakika

    // Retry interceptor ekle
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          debugPrint('Dio error: ${error.message}');
          debugPrint('Error type: ${error.type}');
          debugPrint('Response: ${error.response?.data}');

          // Retry mantığı
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout) {
            // 3 kez dene
            final retryCount = error.requestOptions.extra['retryCount'] ?? 0;
            if (retryCount < 3) {
              error.requestOptions.extra['retryCount'] = retryCount + 1;
              debugPrint('Retrying request (attempt ${retryCount + 1})');

              // 2 saniye bekle
              await Future.delayed(const Duration(seconds: 2));

              try {
                final response = await _dio.fetch(error.requestOptions);
                handler.resolve(response);
                return;
              } catch (e) {
                // Retry başarısız, orijinal hatayı devam ettir
              }
            }
          }

          handler.next(error);
        },
      ),
    );

    debugPrint('DownloadService initialized with enhanced error handling');
  }

  // Storage permission kontrol et - geliştirilmiş versiyon
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      try {
        // Android API seviyesini kontrol et
        bool hasPermission = false;

        // Modern Android için
        final audioPermission = await Permission.audio.status;
        if (audioPermission == PermissionStatus.granted) {
          hasPermission = true;
        } else {
          final result = await Permission.audio.request();
          hasPermission = result == PermissionStatus.granted;
        }

        // Eğer audio izni yoksa, en azından internal storage kullanabiliriz
        if (!hasPermission) {
          debugPrint('Audio permission denied, using internal storage');
          hasPermission = true; // Internal storage için her zaman true
        }

        debugPrint('Storage permission status: $hasPermission');
        return hasPermission;
      } catch (e) {
        debugPrint('Permission error: $e');
        return true; // Hata durumunda internal storage kullan
      }
    }
    return true; // iOS için otomatik true
  }

  // Download klasörü al - geliştirilmiş versiyon
  static Future<Directory> _getDownloadDirectory() async {
    Directory? directory;

    try {
      if (Platform.isAndroid) {
        // Önce external storage'ı dene
        try {
          directory = await getExternalStorageDirectory();
          if (directory != null) {
            final musicDir = Directory('${directory.path}/PitonMusic');
            if (!await musicDir.exists()) {
              await musicDir.create(recursive: true);
            }
            debugPrint('Using external storage: ${musicDir.path}');
            return musicDir;
          }
        } catch (e) {
          debugPrint('External storage error: $e');
        }
      }

      // External storage yoksa application documents'i kullan
      try {
        directory = await getApplicationDocumentsDirectory();
        final musicDir = Directory('${directory.path}/PitonMusic');
        if (!await musicDir.exists()) {
          await musicDir.create(recursive: true);
        }
        debugPrint('Using documents directory: ${musicDir.path}');
        return musicDir;
      } catch (e) {
        debugPrint('Documents directory error: $e');
      }

      // Son çare: temporary directory
      directory = await getTemporaryDirectory();
      final musicDir = Directory('${directory.path}/PitonMusic');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }
      debugPrint('Using temporary directory: ${musicDir.path}');
      return musicDir;
    } catch (e) {
      debugPrint('Critical error getting directory: $e');
      // En son çare olarak mevcut dizini kullan
      directory = Directory.current;
      final musicDir = Directory('${directory.path}/PitonMusic');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }
      return musicDir;
    }
  }

  // URL'in geçerli olup olmadığını kontrol et
  static bool _isValidUrl(String url) {
    if (url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  // URL'i test et
  static Future<bool> _testUrl(String url) async {
    try {
      final response = await _dio.head(
        url,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final isValid = response.statusCode == 200;
      debugPrint('URL test for $url: ${isValid ? 'valid' : 'invalid'}');

      if (isValid) {
        final contentLength = response.headers.value('content-length');
        debugPrint('Content length: $contentLength bytes');
      }

      return isValid;
    } catch (e) {
      debugPrint('URL test failed for $url: $e');
      return false;
    }
  }

  // Müzik indir - geliştirilmiş versiyon
  static Future<bool> downloadMusic(Music music) async {
    try {
      debugPrint('=== DOWNLOAD START ===');
      debugPrint('Music ID: ${music.id}');
      debugPrint('Music Title: ${music.title}');
      debugPrint('Stream URL: ${music.streamUrl}');
      debugPrint('Download URL: ${music.downloadUrl}');

      // İnternet bağlantısını kontrol et
      final isConnected = await ConnectivityService.checkConnection();
      if (!isConnected) {
        debugPrint('❌ No internet connection');
        return false;
      }
      debugPrint('✅ Internet connection available');

      // Permission kontrol et
      if (!await _requestStoragePermission()) {
        debugPrint('❌ Storage permission denied');
        return false;
      }
      debugPrint('✅ Storage permission granted');

      // Zaten indiriliyor mu kontrol et
      if (_activeDownloads.containsKey(music.id)) {
        debugPrint('❌ Music already downloading: ${music.title}');
        return false;
      }

      // Zaten indirilmiş mi kontrol et
      if (await isDownloaded(music.id)) {
        debugPrint('✅ Music already downloaded: ${music.title}');
        return true;
      }

      debugPrint('🚀 Starting download: ${music.title}');

      // Download directory al
      final downloadDir = await _getDownloadDirectory();
      debugPrint('📁 Download directory: ${downloadDir.path}');

      // Dosya adını oluştur (geliştirilmiş güvenli karakterler)
      final safeFileName = _sanitizeFileName(
        '${music.artist} - ${music.title}.mp3',
      );
      final filePath = '${downloadDir.path}/$safeFileName';
      debugPrint('📄 File path: $filePath');

      // Download URL'lerini belirle ve test et
      List<String> urlsToTry = [];

      if (_isValidUrl(music.downloadUrl)) {
        urlsToTry.add(music.downloadUrl);
      }

      if (_isValidUrl(music.streamUrl) &&
          music.streamUrl != music.downloadUrl) {
        urlsToTry.add(music.streamUrl);
      }

      if (urlsToTry.isEmpty) {
        debugPrint('❌ No valid URLs for download');
        return false;
      }

      debugPrint('🔍 Testing ${urlsToTry.length} URL(s)...');

      String? validUrl;
      for (final url in urlsToTry) {
        // Her URL testi öncesi bağlantıyı tekrar kontrol et
        if (!await ConnectivityService.checkConnection()) {
          debugPrint('❌ Internet connection lost during URL testing');
          return false;
        }

        if (await _testUrl(url)) {
          validUrl = url;
          break;
        }
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // URL'ler arası bekleme
      }

      if (validUrl == null) {
        debugPrint('❌ No working URL found');
        return false;
      }

      debugPrint('🌐 Using URL: $validUrl');

      // Cancel token oluştur
      final cancelToken = CancelToken();
      _activeDownloads[music.id] = cancelToken;

      // Progress tracking
      final Map<String, double> progressMap = {};

      // Download başlat
      await _dio.download(
        validUrl,
        filePath,
        cancelToken: cancelToken,
        options: Options(
          headers: {'User-Agent': 'PitonMusic/1.0', 'Accept': '*/*'},
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            progressMap[music.id] = progress;
            _progressController.add(Map.from(progressMap));
            debugPrint(
              '📊 Download progress: ${(progress * 100).toStringAsFixed(1)}% ($received/$total bytes)',
            );
          } else {
            // Total bilinmiyor, sadece indirilen byte'ları göster
            debugPrint('📊 Downloaded: ${_formatBytes(received)}');
          }
        },
      );

      // Download tamamlandı, dosya varlığını kontrol et
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ Downloaded file not found');
        _activeDownloads.remove(music.id);
        return false;
      }

      final fileSize = await file.length();
      if (fileSize < 1024) {
        // 1KB'den küçükse problem var
        debugPrint('❌ Downloaded file too small: $fileSize bytes');
        await file.delete();
        _activeDownloads.remove(music.id);
        return false;
      }

      // Download tamamlandı
      _activeDownloads.remove(music.id);

      // İndirilen müziği kaydet
      await _saveDownloadedMusic(music, filePath);

      debugPrint(
        '✅ Download completed: ${music.title} (${_formatBytes(fileSize)})',
      );
      debugPrint('=== DOWNLOAD END ===');
      return true;
    } catch (e) {
      debugPrint('❌ Download error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      if (e is DioException) {
        debugPrint('Dio error type: ${e.type}');
        debugPrint('Dio error message: ${e.message}');
        debugPrint('Response status: ${e.response?.statusCode}');
        debugPrint('Response data: ${e.response?.data}');

        // İnternet bağlantısı kesildi mi kontrol et
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          final isStillConnected = await ConnectivityService.checkConnection();
          if (!isStillConnected) {
            debugPrint('❌ Internet connection lost during download');
          }
        }
      }
      _activeDownloads.remove(music.id);
      return false;
    }
  }

  // Dosya adını güvenli hale getir - geliştirilmiş versiyon
  static String _sanitizeFileName(String fileName) {
    // Özel karakterleri temizle
    String safe =
        fileName
            .replaceAll(
              RegExp(r'[<>:"/\\|?*]'),
              '_',
            ) // Windows yasak karakterleri
            .replaceAll(
              RegExp(r'[^\w\s\-\.]'),
              '_',
            ) // Alfanumerik olmayan karakterler
            .replaceAll(RegExp(r'\s+'), '_') // Boşlukları alt çizgi yap
            .replaceAll(RegExp(r'_{2,}'), '_') // Çift alt çizgileri tek yap
            .trim();

    // Dosya adının çok uzun olmamasını sağla
    if (safe.length > 100) {
      final extension = safe.substring(safe.lastIndexOf('.'));
      safe = safe.substring(0, 100 - extension.length) + extension;
    }

    // Dosya adının boş olmamasını sağla
    if (safe.isEmpty || safe == '.mp3') {
      safe = 'unknown_music.mp3';
    }

    debugPrint('Sanitized filename: $fileName -> $safe');
    return safe;
  }

  // İndirilen müziği SharedPreferences'a kaydet
  static Future<void> _saveDownloadedMusic(Music music, String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadedList = await getDownloadedMusics();

      // Yerel dosya yolu ile birlikte müziği kaydet
      final downloadedMusic = Music(
        id: music.id,
        title: music.title,
        artist: music.artist,
        album: music.album,
        imageUrl: music.imageUrl,
        streamUrl: filePath, // Yerel dosya yolu
        downloadUrl: filePath, // Yerel dosya yolu
        genre: music.genre,
        duration: music.duration,
      );

      downloadedList.add(downloadedMusic);

      final jsonList = downloadedList.map((m) => m.toJson()).toList();
      await prefs.setString(_downloadListKey, json.encode(jsonList));

      debugPrint('Saved downloaded music: ${music.title}');
    } catch (e) {
      debugPrint('Error saving downloaded music: $e');
    }
  }

  // İndirilen müzikleri getir
  static Future<List<Music>> getDownloadedMusics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_downloadListKey);

      if (jsonString == null) return [];

      final List<dynamic> jsonList = json.decode(jsonString);
      final musics = jsonList.map((json) => Music.fromJson(json)).toList();

      // Dosya varlığını kontrol et
      final validMusics = <Music>[];
      for (final music in musics) {
        final file = File(music.streamUrl);
        if (await file.exists()) {
          validMusics.add(music);
        }
      }

      // Geçersiz dosyalar varsa listeyi güncelle
      if (validMusics.length != musics.length) {
        await _updateDownloadedMusicsList(validMusics);
      }

      return validMusics;
    } catch (e) {
      debugPrint('Error getting downloaded musics: $e');
      return [];
    }
  }

  // İndirilen müzikler listesini güncelle
  static Future<void> _updateDownloadedMusicsList(List<Music> musics) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = musics.map((m) => m.toJson()).toList();
      await prefs.setString(_downloadListKey, json.encode(jsonList));
    } catch (e) {
      debugPrint('Error updating downloaded musics list: $e');
    }
  }

  // Müzik indirilmiş mi kontrol et
  static Future<bool> isDownloaded(String musicId) async {
    final downloadedMusics = await getDownloadedMusics();
    return downloadedMusics.any((music) => music.id == musicId);
  }

  // İndirilen müziği sil
  static Future<bool> deleteDownloadedMusic(String musicId) async {
    try {
      final downloadedMusics = await getDownloadedMusics();
      final musicToDelete = downloadedMusics.firstWhere(
        (music) => music.id == musicId,
        orElse: () => throw Exception('Music not found'),
      );

      // Dosyayı sil
      final file = File(musicToDelete.streamUrl);
      if (await file.exists()) {
        await file.delete();
      }

      // Listeden çıkar
      downloadedMusics.removeWhere((music) => music.id == musicId);
      await _updateDownloadedMusicsList(downloadedMusics);

      debugPrint('Deleted downloaded music: ${musicToDelete.title}');
      return true;
    } catch (e) {
      debugPrint('Error deleting downloaded music: $e');
      return false;
    }
  }

  // Tüm indirmeleri sil
  static Future<bool> deleteAllDownloads() async {
    try {
      final downloadedMusics = await getDownloadedMusics();

      for (final music in downloadedMusics) {
        final file = File(music.streamUrl);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // SharedPreferences'ı temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_downloadListKey);

      debugPrint('Deleted all downloads');
      return true;
    } catch (e) {
      debugPrint('Error deleting all downloads: $e');
      return false;
    }
  }

  // Download'ı iptal et
  static Future<void> cancelDownload(String musicId) async {
    final cancelToken = _activeDownloads[musicId];
    if (cancelToken != null) {
      cancelToken.cancel();
      _activeDownloads.remove(musicId);
      debugPrint('Cancelled download for music: $musicId');
    }
  }

  // Aktif indirmeler var mı?
  static bool get hasActiveDownloads => _activeDownloads.isNotEmpty;

  // Toplam indirilen müzik sayısı
  static Future<int> getDownloadedCount() async {
    final musics = await getDownloadedMusics();
    return musics.length;
  }

  // Toplam indirilen dosya boyutu
  static Future<String> getTotalDownloadSize() async {
    try {
      final downloadedMusics = await getDownloadedMusics();
      int totalBytes = 0;

      for (final music in downloadedMusics) {
        final file = File(music.streamUrl);
        if (await file.exists()) {
          totalBytes += await file.length();
        }
      }

      return _formatBytes(totalBytes);
    } catch (e) {
      debugPrint('Error calculating download size: $e');
      return '0 MB';
    }
  }

  // Byte'ları okunabilir formata çevir
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Cleanup
  static void dispose() {
    _progressController.close();
  }
}
