import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/music.dart';
import '../services/favorites_service.dart';
import '../services/download_service.dart';
import '../services/theme_service.dart';
import '../services/connectivity_service.dart';
import 'dart:async';

class MusicCard extends StatefulWidget {
  final Music music;
  final VoidCallback onTap;
  final bool showFavoriteButton;
  final bool showDownloadButton;

  const MusicCard({
    super.key,
    required this.music,
    required this.onTap,
    this.showFavoriteButton = true,
    this.showDownloadButton = true,
  });

  @override
  State<MusicCard> createState() => _MusicCardState();
}

class _MusicCardState extends State<MusicCard> {
  bool isFavorite = false;
  bool isDownloaded = false;
  bool isDownloading = false;
  double downloadProgress = 0.0;
  late StreamSubscription<Map<String, double>> _progressSubscription;

  @override
  void initState() {
    super.initState();
    _loadStates();

    // Progress stream'i dinle
    _progressSubscription = DownloadService.downloadProgressStream.listen((
      progressMap,
    ) {
      final musicProgress = progressMap[widget.music.id];
      if (musicProgress != null && mounted) {
        setState(() {
          downloadProgress = musicProgress;
        });
      }
    });
  }

  @override
  void dispose() {
    _progressSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadStates() async {
    await _checkFavoriteStatus();
    await _checkDownloadStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final favorite = await FavoritesService.isFavorite(widget.music.id);
    if (mounted) {
      setState(() {
        isFavorite = favorite;
      });
    }
  }

  Future<void> _checkDownloadStatus() async {
    final downloaded = await DownloadService.isDownloaded(widget.music.id);
    if (mounted) {
      setState(() {
        isDownloaded = downloaded;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (isFavorite) {
      await FavoritesService.removeFromFavorites(widget.music.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.music.title} favorilerden kaldırıldı'),
            backgroundColor: const Color(0xFF6C5CE7),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      await FavoritesService.addToFavorites(widget.music);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.music.title} favorilere eklendi'),
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
  }

  Future<void> _toggleDownload() async {
    if (isDownloaded) {
      // Delete downloaded music
      setState(() {
        isDownloading = true;
      });

      final success = await DownloadService.deleteDownloadedMusic(
        widget.music.id,
      );
      if (mounted) {
        setState(() {
          isDownloading = false;
          isDownloaded = !success ? isDownloaded : false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '${widget.music.title} cihazdan silindi'
                  : 'Silme işlemi başarısız',
            ),
            backgroundColor: success ? const Color(0xFF6C5CE7) : Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      // Start download - asenkron olarak yaparak parent state'i etkilemeyi önle
      setState(() {
        isDownloading = true;
        downloadProgress = 0.0;
      });

      // Download işlemini background'da çalıştır
      _performDownload();
    }
  }

  Future<void> _performDownload() async {
    try {
      debugPrint('🎵 Starting download for: ${widget.music.title}');

      // İnternet bağlantısını kontrol et
      final hasInternet = await ConnectivityService.checkConnection();
      if (!hasInternet) {
        if (mounted) {
          setState(() {
            isDownloading = false;
            downloadProgress = 0.0;
          });

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'İnternet bağlantısı gerekli: ${widget.music.title}',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'İndirilenler',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.pushNamed(context, '/downloads');
                  },
                ),
              ),
            );
          }
        }
        return;
      }

      final success = await DownloadService.downloadMusic(widget.music);

      if (mounted) {
        setState(() {
          isDownloading = false;
          isDownloaded = success;
          downloadProgress = success ? 1.0 : 0.0;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    success ? Icons.download_done : Icons.error_outline,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          success ? 'İndirme tamamlandı!' : 'İndirme başarısız',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.music.title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: success ? Colors.green : Colors.red,
              duration: Duration(seconds: success ? 2 : 3),
              action:
                  success
                      ? SnackBarAction(
                        label: 'Göster',
                        textColor: Colors.white,
                        onPressed: () {
                          Navigator.pushNamed(context, '/downloads');
                        },
                      )
                      : null,
            ),
          );
        }

        debugPrint(
          '🎵 Download completed for: ${widget.music.title} - Success: $success',
        );
      }
    } catch (e) {
      debugPrint('❌ Download error for ${widget.music.title}: $e');

      if (mounted) {
        setState(() {
          isDownloading = false;
          downloadProgress = 0.0;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'İndirme hatası',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.music.title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Tekrar Dene',
                textColor: Colors.white,
                onPressed: () {
                  _performDownload();
                },
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ThemeService.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album Art
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child:
                        widget.music.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: widget.music.imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF6C5CE7),
                                          Color(0xFF00B4D8),
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF6C5CE7),
                                          Color(0xFF00B4D8),
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.music_note,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  ),
                            )
                            : Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF6C5CE7),
                                    Color(0xFF00B4D8),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.music_note,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                  ),
                  // Favorite Button
                  if (widget.showFavoriteButton)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _toggleFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),

                  // Download Button
                  if (widget.showDownloadButton)
                    Positioned(
                      top:
                          widget.showFavoriteButton
                              ? 52
                              : 8, // Favorite butonundan sonra
                      right: 8,
                      child: GestureDetector(
                        onTap: _toggleDownload,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child:
                              isDownloading
                                  ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      value: downloadProgress,
                                      strokeWidth: 2,
                                      color: Colors.white,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  )
                                  : Icon(
                                    isDownloaded
                                        ? Icons.download_done
                                        : Icons.download,
                                    color:
                                        isDownloaded
                                            ? Colors.green
                                            : Colors.white,
                                    size: 18,
                                  ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.music.title,
                      style: TextStyle(
                        color: ThemeService.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.music.artist,
                      style: TextStyle(
                        color: ThemeService.subtitleColor,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.music.genre.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.music.genre,
                          style: const TextStyle(
                            color: Color(0xFF6C5CE7),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
