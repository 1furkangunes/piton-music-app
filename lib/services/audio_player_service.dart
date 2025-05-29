import 'package:just_audio/just_audio.dart';
import '../models/music.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AudioPlayerService {
  static AudioPlayer? _player;
  static Music? _currentMusic;
  static bool _isInitialized = false;
  static Completer<void>? _initCompleter;

  static List<Music>? _currentPlaylist;
  static int? _currentIndex;
  static StreamSubscription? _playerStateSubscription;

  static Timer? _listeningTimer;
  static int _sessionListeningSeconds = 0;
  static const String _totalListeningTimeKey = 'total_listening_time_seconds';

  static final StreamController<Music?> _currentMusicController =
      StreamController<Music?>.broadcast();

  static AudioPlayer get _audioPlayer {
    _player ??= AudioPlayer();
    return _player!;
  }

  static void _setupAutoPlayNext() {
    _playerStateSubscription?.cancel();
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playNextInPlaylist();
      }
    });
  }

  static void _playNextInPlaylist() async {
    if (_currentPlaylist == null || _currentIndex == null) return;

    try {
      final nextIndex = (_currentIndex! + 1) % _currentPlaylist!.length;
      final nextMusic = _currentPlaylist![nextIndex];

      _currentIndex = nextIndex;
      await playMusic(nextMusic);
    } catch (e) {
      debugPrint('Error auto-playing next: $e');
    }
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      _audioPlayer;
      _setupAutoPlayNext();
      _isInitialized = true;
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('Failed to initialize AudioPlayerService: $e');
      _initCompleter!.completeError(e);
    }
  }

  static Future<void> playMusic(
    Music music, {
    List<Music>? playlist,
    int? index,
  }) async {
    try {
      await initialize();

      if (_currentMusic != null) {
        await _stopListeningSession();
      }

      _currentMusic = music;
      _currentMusicController.add(_currentMusic);

      if (playlist != null) {
        _currentPlaylist = playlist;
        _currentIndex = index ?? 0;
      }

      if (music.streamUrl.isNotEmpty) {
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(music.streamUrl);
        await _audioPlayer.play();
        _startListeningSession();
      }
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  static Future<void> pause() async {
    try {
      if (_player != null && _player!.playing) {
        await _player!.pause();
      }
    } catch (e) {
      debugPrint('Pause error: $e');
    }
  }

  static Future<void> resume() async {
    try {
      if (_player != null) {
        await _player!.play();
      }
    } catch (e) {
      debugPrint('Resume error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      if (_player != null) {
        await _player!.stop();
        await _stopListeningSession();
        _currentMusic = null;
      }
    } catch (e) {
      debugPrint('Stop error: $e');
    }
  }

  static Future<void> seek(Duration position) async {
    try {
      if (_player != null) {
        await _player!.seek(position);
      }
    } catch (e) {
      debugPrint('Seek error: $e');
    }
  }

  static Future<void> setVolume(double volume) async {
    try {
      if (_player != null) {
        await _player!.setVolume(volume.clamp(0.0, 1.0));
      }
    } catch (e) {
      debugPrint('Volume error: $e');
    }
  }

  static void _startListeningSession() {
    _sessionListeningSeconds = 0;
    _listeningTimer?.cancel();
    _listeningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_player?.playing == true) {
        _sessionListeningSeconds++;
      }
    });
  }

  static Future<void> _stopListeningSession() async {
    _listeningTimer?.cancel();
    if (_sessionListeningSeconds > 0) {
      await _saveListeningTime(_sessionListeningSeconds);
    }
    _sessionListeningSeconds = 0;
  }

  static Future<void> _saveListeningTime(int seconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentTotal = prefs.getInt(_totalListeningTimeKey) ?? 0;
      final newTotal = currentTotal + seconds;
      await prefs.setInt(_totalListeningTimeKey, newTotal);
    } catch (e) {
      debugPrint('Error saving listening time: $e');
    }
  }

  static Future<int> getTotalListeningTimeSeconds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_totalListeningTimeKey) ?? 0;
    } catch (e) {
      debugPrint('Error getting listening time: $e');
      return 0;
    }
  }

  static Future<double> getTotalListeningTimeHours() async {
    final seconds = await getTotalListeningTimeSeconds();
    return seconds / 3600.0;
  }

  static Future<String> getFormattedListeningTime() async {
    final hours = await getTotalListeningTimeHours();
    if (hours < 1) {
      final minutes = (hours * 60).round();
      return '${minutes}m';
    } else {
      return '${hours.toStringAsFixed(1)}h';
    }
  }

  static Music? get currentMusic => _currentMusic;
  static bool get isPlaying => _player?.playing ?? false;
  static List<Music>? get currentPlaylist => _currentPlaylist;
  static int? get currentIndex => _currentIndex;
  static bool get hasNext =>
      _currentPlaylist != null && _currentPlaylist!.length > 1;
  static bool get hasPrevious =>
      _currentPlaylist != null && _currentPlaylist!.length > 1;

  static Stream<Duration> get positionStream =>
      _player?.positionStream ?? Stream.value(Duration.zero);
  static Stream<Duration?> get durationStream =>
      _player?.durationStream ?? Stream.value(null);
  static Stream<PlayerState> get playerStateStream =>
      _player?.playerStateStream ??
      Stream.value(PlayerState(false, ProcessingState.idle));
  static Stream<bool> get playingStream =>
      _player?.playingStream ?? Stream.value(false);
  static Stream<Music?> get currentMusicStream =>
      _currentMusicController.stream;

  static Future<void> dispose() async {
    await _stopListeningSession();
    _playerStateSubscription?.cancel();
    _listeningTimer?.cancel();
    await _player?.dispose();
    _player = null;
    _currentMusic = null;
    _isInitialized = false;
  }

  static Future<void> reset() async {
    try {
      await dispose();
      await initialize();
    } catch (e) {
      debugPrint('Reset error: $e');
    }
  }
}
