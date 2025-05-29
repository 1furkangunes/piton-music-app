import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/music.dart';
import '../services/audio_player_service.dart';
import '../services/favorites_service.dart';
import '../services/theme_service.dart';
import '../screens/now_playing_screen.dart';
import 'dart:async';

class MiniPlayerBar extends StatefulWidget {
  final int currentIndex;

  const MiniPlayerBar({super.key, required this.currentIndex});

  @override
  State<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends State<MiniPlayerBar> {
  bool isPlaying = false;
  bool isFavorite = false;
  Music? currentMusic;
  int? currentIndex;

  StreamSubscription? _playingSubscription;
  StreamSubscription? _currentMusicSubscription;

  // Debounce için timestamp
  DateTime? _lastNavigationTime;

  // Debounce kontrolü - 300ms içinde tıklamaya izin verme
  bool get _canNavigate {
    if (_lastNavigationTime == null) return true;
    return DateTime.now().difference(_lastNavigationTime!) >
        const Duration(milliseconds: 300);
  }

  @override
  void initState() {
    super.initState();
    currentMusic = AudioPlayerService.currentMusic;
    currentIndex = widget.currentIndex;
    _listenToPlayerState();
    _checkFavoriteStatus();
  }

  @override
  void dispose() {
    _playingSubscription?.cancel();
    _currentMusicSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final music = AudioPlayerService.currentMusic;
    if (music != null) {
      // Skip logging
    }
  }

  void _listenToPlayerState() {
    _playingSubscription = AudioPlayerService.playingStream.listen((playing) {
      if (mounted) {
        setState(() {
          isPlaying = playing;
          // Update current music from audio service
          currentMusic = AudioPlayerService.currentMusic;
        });
        _checkFavoriteStatus();
      }
    });

    // Listen to current music changes for auto-play
    _currentMusicSubscription = AudioPlayerService.currentMusicStream.listen((
      music,
    ) {
      if (mounted && music != null) {
        setState(() {
          currentMusic = music;
          // Update index if playlist is available
          if (currentMusic != null) {
            final newIndex = AudioPlayerService.currentPlaylist?.indexWhere(
              (m) => m.id == music.id,
            );
            if (newIndex != -1) {
              currentIndex = newIndex;
            }
          }
        });
        _checkFavoriteStatus();
      }
    });
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

      setState(() {
        isFavorite = !isFavorite;
      });
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  void _playNext() async {
    // AudioPlayerService'den mevcut playlist'i al
    final currentPlaylist = AudioPlayerService.currentPlaylist;
    if (currentPlaylist == null || !_canNavigate) return;

    _lastNavigationTime = DateTime.now();

    try {
      // Mevcut müziğin playlist'teki gerçek indexini bul
      int realCurrentIndex = 0;
      if (currentMusic != null) {
        realCurrentIndex = currentPlaylist.indexWhere(
          (music) => music.id == currentMusic!.id,
        );
        if (realCurrentIndex == -1) realCurrentIndex = 0;
      }

      final nextIndex = (realCurrentIndex + 1) % currentPlaylist.length;
      final nextMusic = currentPlaylist[nextIndex];

      debugPrint('Playing next: ${nextMusic.title} (index: $nextIndex)');

      await AudioPlayerService.playMusic(
        nextMusic,
        playlist: currentPlaylist,
        index: nextIndex,
      );

      // State'i hemen güncelle
      if (mounted) {
        setState(() {
          currentMusic = nextMusic;
          currentIndex = nextIndex;
        });
      }

      _checkFavoriteStatus();
    } catch (e) {
      debugPrint('Error playing next: $e');
    }
  }

  void _playPrevious() async {
    // AudioPlayerService'den mevcut playlist'i al
    final currentPlaylist = AudioPlayerService.currentPlaylist;
    if (currentPlaylist == null || !_canNavigate) return;

    _lastNavigationTime = DateTime.now();

    try {
      // Mevcut müziğin playlist'teki gerçek indexini bul
      int realCurrentIndex = 0;
      if (currentMusic != null) {
        realCurrentIndex = currentPlaylist.indexWhere(
          (music) => music.id == currentMusic!.id,
        );
        if (realCurrentIndex == -1) realCurrentIndex = 0;
      }

      final prevIndex =
          realCurrentIndex == 0
              ? currentPlaylist.length - 1
              : realCurrentIndex - 1;
      final prevMusic = currentPlaylist[prevIndex];

      debugPrint('Playing previous: ${prevMusic.title} (index: $prevIndex)');

      await AudioPlayerService.playMusic(
        prevMusic,
        playlist: currentPlaylist,
        index: prevIndex,
      );

      // State'i hemen güncelle
      if (mounted) {
        setState(() {
          currentMusic = prevMusic;
          currentIndex = prevIndex;
        });
      }

      _checkFavoriteStatus();
    } catch (e) {
      debugPrint('Error playing previous: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentMusic == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: ThemeService.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Album Art
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => NowPlayingScreen(
                        music: currentMusic!,
                        playlist:
                            AudioPlayerService.currentPlaylist ??
                            [currentMusic!],
                        currentIndex: currentIndex,
                      ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: currentMusic!.imageUrl,
                width: 45,
                height: 45,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Container(
                      width: 45,
                      height: 45,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFF00B4D8)],
                        ),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      width: 45,
                      height: 45,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFF00B4D8)],
                        ),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Song Info
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => NowPlayingScreen(
                          music: currentMusic!,
                          playlist:
                              AudioPlayerService.currentPlaylist ??
                              [currentMusic!],
                          currentIndex: currentIndex,
                        ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentMusic!.title,
                    style: TextStyle(
                      color: ThemeService.textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    currentMusic!.artist,
                    style: TextStyle(
                      color: ThemeService.subtitleColor,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous Button
              IconButton(
                onPressed:
                    (AudioPlayerService.currentPlaylist != null &&
                            AudioPlayerService.currentPlaylist!.length > 1)
                        ? _playPrevious
                        : null,
                icon: Icon(
                  Icons.skip_previous,
                  color:
                      (AudioPlayerService.currentPlaylist != null &&
                              AudioPlayerService.currentPlaylist!.length > 1)
                          ? ThemeService.textColor
                          : ThemeService.textColor.withValues(alpha: 0.4),
                ),
              ),

              const SizedBox(width: 6),

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
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF6C5CE7),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Next Button
              IconButton(
                onPressed:
                    (AudioPlayerService.currentPlaylist != null &&
                            AudioPlayerService.currentPlaylist!.length > 1)
                        ? _playNext
                        : null,
                icon: Icon(
                  Icons.skip_next,
                  color:
                      (AudioPlayerService.currentPlaylist != null &&
                              AudioPlayerService.currentPlaylist!.length > 1)
                          ? ThemeService.textColor
                          : ThemeService.textColor.withValues(alpha: 0.4),
                ),
              ),

              const SizedBox(width: 6),

              // Favorite Button
              GestureDetector(
                onTap: _toggleFavorite,
                child: Container(
                  padding: const EdgeInsets.all(6),
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
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
