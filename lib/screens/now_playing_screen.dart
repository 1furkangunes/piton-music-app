import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/music.dart';
import '../services/audio_player_service.dart';
import '../services/favorites_service.dart';
import '../services/theme_service.dart';
import 'dart:async';

class NowPlayingScreen extends StatefulWidget {
  final Music music;
  final List<Music>? playlist;
  final int? currentIndex;

  const NowPlayingScreen({
    super.key,
    required this.music,
    this.playlist,
    this.currentIndex,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;
  bool isFavorite = false;
  Music? currentMusic;
  int? currentIndex;

  // StreamSubscriptions for proper disposal
  late StreamSubscription? _playingSubscription;
  late StreamSubscription? _positionSubscription;
  late StreamSubscription? _durationSubscription;
  late StreamSubscription? _currentMusicSubscription;

  @override
  void initState() {
    super.initState();
    currentMusic = widget.music;
    currentIndex = widget.currentIndex;
    _listenToPlayerState();
    _checkFavoriteStatus();
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent memory leaks
    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _currentMusicSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkFavoriteStatus() async {
    if (currentMusic != null) {
      final favorite = await FavoritesService.isFavorite(currentMusic!.id);
      if (mounted) {
        setState(() {
          isFavorite = favorite;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (currentMusic == null) return;

    try {
      if (isFavorite) {
        await FavoritesService.removeFromFavorites(currentMusic!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${currentMusic!.title} favorilerden kaldırıldı'),
              backgroundColor: const Color(0xFF6C5CE7),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        await FavoritesService.addToFavorites(currentMusic!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${currentMusic!.title} favorilere eklendi'),
              backgroundColor: const Color(0xFF6C5CE7),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          isFavorite = !isFavorite;
        });
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  void _playNext() async {
    // AudioPlayerService'den playlist'i al
    final currentPlaylist = AudioPlayerService.currentPlaylist;
    if (currentPlaylist == null) return;

    try {
      // Mevcut müziğin playlist'teki gerçek indexini bul
      int realCurrentIndex = 0;
      if (currentMusic != null) {
        realCurrentIndex = currentPlaylist.indexWhere(
          (music) => music.id == currentMusic!.id,
        );
        if (realCurrentIndex == -1) realCurrentIndex = 0;
      }

      // Circular navigation: son şarkıdan sonra ilk şarkıya geç
      final nextIndex = (realCurrentIndex + 1) % currentPlaylist.length;
      final nextMusic = currentPlaylist[nextIndex];

      // UI'yi hemen güncelle (gecikmeyi önle)
      if (mounted) {
        setState(() {
          currentMusic = nextMusic;
          currentIndex = nextIndex;
          isPlaying = false; // Loading state için
        });
      }

      // Ses çalmaya başla
      await AudioPlayerService.playMusic(
        nextMusic,
        playlist: currentPlaylist,
        index: nextIndex,
      );

      // Favori durumunu kontrol et
      _checkFavoriteStatus();

      if (nextIndex == 0) {
        debugPrint(
          'Next: Wrapped to start - index $nextIndex - ${nextMusic.title}',
        );
      } else {
        debugPrint('Next: Moved to index $nextIndex - ${nextMusic.title}');
      }
    } catch (e) {
      debugPrint('Error playing next: $e');
    }
  }

  void _playPrevious() async {
    // AudioPlayerService'den playlist'i al
    final currentPlaylist = AudioPlayerService.currentPlaylist;
    if (currentPlaylist == null) return;

    try {
      // Mevcut müziğin playlist'teki gerçek indexini bul
      int realCurrentIndex = 0;
      if (currentMusic != null) {
        realCurrentIndex = currentPlaylist.indexWhere(
          (music) => music.id == currentMusic!.id,
        );
        if (realCurrentIndex == -1) realCurrentIndex = 0;
      }

      // Circular navigation: ilk şarkıdan önce son şarkıya geç
      final prevIndex =
          realCurrentIndex == 0
              ? currentPlaylist.length - 1
              : realCurrentIndex - 1;
      final prevMusic = currentPlaylist[prevIndex];

      // UI'yi hemen güncelle (gecikmeyi önle)
      if (mounted) {
        setState(() {
          currentMusic = prevMusic;
          currentIndex = prevIndex;
          isPlaying = false; // Loading state için
        });
      }

      // Ses çalmaya başla
      await AudioPlayerService.playMusic(
        prevMusic,
        playlist: currentPlaylist,
        index: prevIndex,
      );

      // Favori durumunu kontrol et
      _checkFavoriteStatus();

      if (realCurrentIndex == 0 && prevIndex == currentPlaylist.length - 1) {
        debugPrint(
          'Previous: Wrapped to end - index $prevIndex - ${prevMusic.title}',
        );
      } else {
        debugPrint('Previous: Moved to index $prevIndex - ${prevMusic.title}');
      }
    } catch (e) {
      debugPrint('Error playing previous: $e');
    }
  }

  void _listenToPlayerState() {
    try {
      // Listen to playing state
      _playingSubscription = AudioPlayerService.playingStream.listen((playing) {
        if (mounted) {
          setState(() {
            isPlaying = playing;
          });
        }
      });

      // Listen to position
      _positionSubscription = AudioPlayerService.positionStream.listen((
        position,
      ) {
        if (mounted) {
          setState(() {
            currentPosition = position;
          });
        }
      });

      // Listen to duration
      _durationSubscription = AudioPlayerService.durationStream.listen((
        duration,
      ) {
        if (mounted && duration != null) {
          setState(() {
            totalDuration = duration;
          });
        }
      });

      // Listen to current music changes (auto-play için)
      _currentMusicSubscription = AudioPlayerService.currentMusicStream.listen((
        music,
      ) {
        if (mounted && music != null) {
          // Auto-play'de müzik değiştiğinde UI'ı güncelle
          final currentPlaylist = AudioPlayerService.currentPlaylist;
          final newIndex = currentPlaylist?.indexWhere((m) => m.id == music.id);
          setState(() {
            currentMusic = music;
            if (newIndex != null && newIndex != -1) {
              currentIndex = newIndex;
            }
          });
          // Favori durumunu kontrol et
          _checkFavoriteStatus();
          debugPrint('Now Playing UI updated: ${music.title}');
        }
      });
    } catch (e) {
      debugPrint('Error setting up audio listeners: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _seekToPosition(TapDownDetails details) async {
    if (totalDuration.inMilliseconds == 0) return;

    try {
      // Waveform container'ının genişliği (50 bar * 3px + 49 spacing * 2px = 248px)
      const waveformWidth = 248.0;
      final screenWidth = MediaQuery.of(context).size.width;

      // Waveform'un ekrandaki başlangıç pozisyonu (ortalanmış)
      final waveformStartX = (screenWidth - waveformWidth) / 2;

      // Tıklanan global pozisyonu al
      final tapX = details.globalPosition.dx;

      // Waveform içindeki relatif pozisyonu hesapla
      final relativeX = tapX - waveformStartX;

      // Progress'i hesapla (0.0 - 1.0 arası)
      final progress = (relativeX / waveformWidth).clamp(0.0, 1.0);

      // Hedef pozisyonu hesapla
      final targetPosition = Duration(
        milliseconds: (totalDuration.inMilliseconds * progress).round(),
      );

      debugPrint(
        'Seeking to: ${_formatDuration(targetPosition)} (${(progress * 100).toStringAsFixed(1)}%)',
      );

      // AudioPlayerService ile pozisyona atla
      await AudioPlayerService.seek(targetPosition);

      // UI'ı hemen güncelle (daha responsive olması için)
      if (mounted) {
        setState(() {
          currentPosition = targetPosition;
        });
      }
    } catch (e) {
      debugPrint('Error seeking to position: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeService.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: ThemeService.textColor,
                      size: 24,
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        'Now Playing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: ThemeService.textColor,
                        ),
                      ),
                      if (AudioPlayerService.currentPlaylist != null &&
                          currentIndex != null)
                        Text(
                          '${currentIndex! + 1} / ${AudioPlayerService.currentPlaylist!.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: ThemeService.subtitleColor,
                          ),
                        ),
                    ],
                  ),
                  Icon(
                    Icons.more_vert,
                    color: ThemeService.textColor,
                    size: 24,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Album Art
            Container(
              width: 300,
              height: 300,
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF6C5CE7),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: currentMusic?.imageUrl ?? '',
                  width: 300,
                  height: 300,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(
                    milliseconds: 200,
                  ), // Hızlı fade-in
                  fadeOutDuration: const Duration(
                    milliseconds: 100,
                  ), // Hızlı fade-out
                  memCacheWidth: 300, // Memory cache optimizasyonu
                  memCacheHeight: 300,
                  placeholder:
                      (context, url) => Container(
                        color: const Color(0xFF6C5CE7),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        color: const Color(0xFF6C5CE7),
                        child: const Icon(
                          Icons.music_note,
                          size: 100,
                          color: Colors.white,
                        ),
                      ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Song Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  Text(
                    currentMusic?.title ?? '',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ThemeService.textColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentMusic?.artist ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: ThemeService.subtitleColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  // Custom Waveform Visual - Tıklanabilir
                  GestureDetector(
                    onTapDown: (details) {
                      _seekToPosition(details);
                    },
                    child: SizedBox(
                      height: 60,
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(50, (index) {
                          final progress =
                              totalDuration.inMilliseconds > 0
                                  ? currentPosition.inMilliseconds /
                                      totalDuration.inMilliseconds
                                  : 0.0;
                          final isActive = index < (50 * progress);
                          final heights = [
                            20.0,
                            40.0,
                            60.0,
                            30.0,
                            50.0,
                            25.0,
                            45.0,
                            35.0,
                          ];
                          final height = heights[index % heights.length];

                          return Container(
                            width: 3,
                            height: height,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color:
                                  isActive
                                      ? ThemeService.textColor
                                      : ThemeService.subtitleColor.withValues(
                                        alpha: 0.5,
                                      ),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Time Labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(currentPosition),
                        style: TextStyle(
                          color: ThemeService.textColor,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _formatDuration(totalDuration),
                        style: TextStyle(
                          color: ThemeService.subtitleColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Control Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Previous Button - Artık her zaman aktif (circular navigation)
                GestureDetector(
                  onTap: _playPrevious,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThemeService.textColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.skip_previous,
                      color: ThemeService.textColor,
                      size: 32,
                    ),
                  ),
                ),

                // Favorite Button
                GestureDetector(
                  onTap: _toggleFavorite,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isFavorite
                              ? Colors.red.withValues(alpha: 0.2)
                              : ThemeService.textColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : ThemeService.textColor,
                      size: 28,
                    ),
                  ),
                ),

                // Play/Pause Button
                GestureDetector(
                  onTap: () async {
                    try {
                      if (isPlaying) {
                        await AudioPlayerService.pause();
                      } else {
                        await AudioPlayerService.resume();
                      }
                    } catch (e) {
                      debugPrint('Error toggling play/pause: $e');
                    }
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF6C5CE7),
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),

                // Shuffle Button (extra feature)
                GestureDetector(
                  onTap: () {
                    // Shuffle functionality - gelecekte eklenebilir
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Karışık çalma özelliği yakında!'),
                        backgroundColor: Color(0xFF6C5CE7),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThemeService.textColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shuffle,
                      color: ThemeService.textColor,
                      size: 28,
                    ),
                  ),
                ),

                // Next Button - Artık her zaman aktif (circular navigation)
                GestureDetector(
                  onTap: _playNext,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThemeService.textColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.skip_next,
                      color: ThemeService.textColor,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
