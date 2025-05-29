import 'package:flutter/material.dart';
import '../models/music.dart';
import '../services/download_service.dart';
import '../services/audio_player_service.dart';
import '../services/theme_service.dart';
import '../widgets/music_card.dart';
import '../utils/responsive.dart';
import 'now_playing_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Music> downloadedMusics = [];
  bool isLoading = true;
  String totalSize = '0 MB';

  @override
  void initState() {
    super.initState();
    _loadDownloadedMusics();
  }

  Future<void> _loadDownloadedMusics() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    try {
      final downloaded = await DownloadService.getDownloadedMusics();
      final size = await DownloadService.getTotalDownloadSize();

      if (!mounted) return;
      setState(() {
        downloadedMusics = downloaded;
        totalSize = size;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      debugPrint('Error loading downloaded musics: $e');
    }
  }

  Future<void> _deleteDownloadedMusic(Music music) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: ThemeService.cardColor,
            title: Text(
              'Müziği Sil',
              style: TextStyle(color: ThemeService.textColor),
            ),
            content: Text(
              '${music.title} adlı müziği cihazınızdan silmek istediğinize emin misiniz?',
              style: TextStyle(color: ThemeService.subtitleColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Color(0xFF6C5CE7)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sil', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final success = await DownloadService.deleteDownloadedMusic(music.id);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${music.title} silindi'),
            backgroundColor: const Color(0xFF6C5CE7),
          ),
        );
        _loadDownloadedMusics();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silme işlemi başarısız'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllDownloads() async {
    if (downloadedMusics.isEmpty) return;

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: ThemeService.cardColor,
            title: Text(
              'Tüm İndirmeleri Sil',
              style: TextStyle(color: ThemeService.textColor),
            ),
            content: Text(
              'Tüm indirilen müzikleri (${downloadedMusics.length} adet) silmek istediğinize emin misiniz?',
              style: TextStyle(color: ThemeService.subtitleColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Color(0xFF6C5CE7)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Hepsini Sil',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final success = await DownloadService.deleteAllDownloads();

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tüm indirmeler silindi'),
            backgroundColor: Color(0xFF6C5CE7),
          ),
        );
        _loadDownloadedMusics();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeService.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: ThemeService.textColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'İndirilenler',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ThemeService.textColor,
                          ),
                        ),
                        Text(
                          '${downloadedMusics.length} müzik • $totalSize',
                          style: TextStyle(
                            fontSize: 14,
                            color: ThemeService.subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (downloadedMusics.isNotEmpty)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: ThemeService.textColor,
                      ),
                      color: ThemeService.cardColor,
                      onSelected: (value) {
                        if (value == 'delete_all') {
                          _deleteAllDownloads();
                        }
                      },
                      itemBuilder:
                          (context) => [
                            PopupMenuItem<String>(
                              value: 'delete_all',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tümünü Sil',
                                    style: TextStyle(
                                      color: ThemeService.textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                    ),
                ],
              ),
            ),

            if (downloadedMusics.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF00B4D8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storage, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Çevrimdışı Müzikler',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Toplam $totalSize kullanılıyor',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${downloadedMusics.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            Expanded(
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6C5CE7),
                        ),
                      )
                      : downloadedMusics.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.download_outlined,
                              size: 80,
                              color: ThemeService.subtitleColor.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz indirilen müzik yok',
                              style: TextStyle(
                                color: ThemeService.subtitleColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Müzikleri çevrimdışı dinlemek için indirin',
                              style: TextStyle(
                                color: ThemeService.subtitleColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                      : GridView.builder(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 100,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              ResponsiveHelper.getGridCrossAxisCount(context),
                          childAspectRatio: ResponsiveHelper.getCardAspectRatio(
                            context,
                          ),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: downloadedMusics.length,
                        itemBuilder: (context, index) {
                          final music = downloadedMusics[index];
                          return Stack(
                            children: [
                              MusicCard(
                                music: music,
                                showFavoriteButton: false,
                                showDownloadButton: false,
                                onTap: () async {
                                  final nav = Navigator.of(context);

                                  await AudioPlayerService.playMusic(
                                    music,
                                    playlist: downloadedMusics,
                                    index: index,
                                  );

                                  if (!mounted) return;
                                  nav.push(
                                    MaterialPageRoute(
                                      builder:
                                          (context) => NowPlayingScreen(
                                            music: music,
                                            playlist: downloadedMusics,
                                            currentIndex: index,
                                          ),
                                    ),
                                  );
                                },
                              ),

                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.download_done,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),

                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => _deleteDownloadedMusic(music),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
