import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../services/audio_player_service.dart';
import '../services/download_service.dart';
import '../services/theme_service.dart';
import 'downloads_screen.dart';
import 'main_navigation_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNavigationScreen(initialIndex: 2);
  }
}

class ProfileScreenContent extends StatefulWidget {
  const ProfileScreenContent({super.key});

  @override
  State<ProfileScreenContent> createState() => _ProfileScreenContentState();
}

class _ProfileScreenContentState extends State<ProfileScreenContent> {
  int favoriteCount = 0;
  int downloadedCount = 0;
  bool isDarkMode = true;
  double volume = 0.7;
  int selectedQuality = 320; // 128, 192, 320 kbps
  String listeningTime = '0m';

  @override
  void initState() {
    super.initState();
    _loadUserStats();
    _loadThemeState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Gerçek dinleme süresini al
    final formattedTime = await AudioPlayerService.getFormattedListeningTime();
    if (!mounted) return;
    setState(() {
      listeningTime = formattedTime;
    });
  }

  Future<void> _loadThemeState() async {
    if (!mounted) return;
    setState(() {
      isDarkMode = ThemeService.isDarkMode;
    });
  }

  Future<void> _loadUserStats() async {
    try {
      final favorites = await FavoritesService.getFavorites();
      final downloaded = await DownloadService.getDownloadedCount();
      final formattedTime =
          await AudioPlayerService.getFormattedListeningTime();
      if (!mounted) return;
      setState(() {
        favoriteCount = favorites.length;
        downloadedCount = downloaded;
        listeningTime = formattedTime;
      });
    } catch (e) {
      debugPrint('Error loading user stats: $e');
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ThemeService.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF6C5CE7), size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: ThemeService.textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: ThemeService.subtitleColor, fontSize: 12),
        ),
        trailing:
            trailing ??
            Icon(
              Icons.arrow_forward_ios,
              color: ThemeService.subtitleColor,
              size: 16,
            ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ThemeService.themeStream,
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: ThemeService.backgroundColor,
          body: LayoutBuilder(
            builder: (context, constraints) {
              return SafeArea(
                child: Column(
                  children: [
                    // Main content with scroll
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(
                          bottom: 100,
                        ), // Bottom navigation için extra padding
                        child: Column(
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Profil',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: ThemeService.textColor,
                                  ),
                                ),
                              ),
                            ),

                            // Profile Avatar & Info
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6C5CE7),
                                    Color(0xFF00B4D8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Müzik Sever',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'PitonMusic Kullanıcısı',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Stats Grid
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                children: [
                                  // İlk satır - 2 kart
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildStatCard(
                                          'Favori Müzikler',
                                          favoriteCount.toString(),
                                          Icons.favorite,
                                          const Color(0xFFE74C3C),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildStatCard(
                                          'İndirilenler',
                                          downloadedCount.toString(),
                                          Icons.download_done,
                                          const Color(0xFF27AE60),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // İkinci satır - 1 kart (ortalanmış)
                                  Row(
                                    children: [
                                      const Spacer(),
                                      Expanded(
                                        flex: 2,
                                        child: _buildStatCard(
                                          'Dinleme Süresi',
                                          listeningTime,
                                          Icons.access_time,
                                          const Color(0xFF3498DB),
                                        ),
                                      ),
                                      const Spacer(),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Settings
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ayarlar',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: ThemeService.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  _buildSettingTile(
                                    title: 'Tema',
                                    subtitle:
                                        isDarkMode ? 'Koyu tema' : 'Açık tema',
                                    icon:
                                        isDarkMode
                                            ? Icons.dark_mode
                                            : Icons.light_mode,
                                    trailing: Switch(
                                      value: isDarkMode,
                                      onChanged: (value) {
                                        setState(() {
                                          isDarkMode = value;
                                        });
                                        ThemeService.toggleTheme();
                                      },
                                      activeColor: const Color(0xFF6C5CE7),
                                    ),
                                  ),

                                  _buildSettingTile(
                                    title: 'Ses Seviyesi',
                                    subtitle: '${(volume * 100).round()}%',
                                    icon: Icons.volume_up,
                                    trailing: SizedBox(
                                      width: 100,
                                      child: Slider(
                                        value: volume,
                                        onChanged: (value) {
                                          setState(() {
                                            volume = value;
                                          });
                                          AudioPlayerService.setVolume(value);
                                        },
                                        activeColor: const Color(0xFF6C5CE7),
                                        inactiveColor: ThemeService
                                            .subtitleColor
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),

                                  _buildSettingTile(
                                    title: 'Müzik Kalitesi',
                                    subtitle: _getQualityText(selectedQuality),
                                    icon: Icons.high_quality,
                                    onTap: _showQualityDialog,
                                  ),

                                  _buildSettingTile(
                                    title: 'Hakkında',
                                    subtitle: 'Uygulama bilgileri',
                                    icon: Icons.info_outline,
                                    onTap: _showAboutDialog,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // App Info Section
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Uygulama',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: ThemeService.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  _buildSettingTile(
                                    title: 'İndirilenler',
                                    subtitle: 'Çevrimdışı müzikler',
                                    icon: Icons.download,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const DownloadsScreen(),
                                        ),
                                      );
                                    },
                                  ),

                                  _buildSettingTile(
                                    title: 'Favorileri Temizle',
                                    subtitle: 'Tüm favori müzikleri sil',
                                    icon: Icons.delete_sweep,
                                    onTap: () {
                                      _showClearFavoritesDialog();
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getQualityText(int quality) {
    switch (quality) {
      case 128:
        return 'Düşük (128kbps)';
      case 192:
        return 'Orta (192kbps)';
      case 320:
        return 'Yüksek (320kbps)';
      default:
        return 'Yüksek (320kbps)';
    }
  }

  void _showQualityDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: ThemeService.cardColor,
            title: Text(
              'Müzik Kalitesi',
              style: TextStyle(color: ThemeService.textColor),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Düşük (128kbps)',
                    style: TextStyle(color: ThemeService.textColor),
                  ),
                  leading: Radio<int>(
                    value: 128,
                    groupValue: selectedQuality,
                    onChanged: (value) {
                      setState(() {
                        selectedQuality = value!;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Müzik kalitesi: ${_getQualityText(selectedQuality)}',
                          ),
                          backgroundColor: const Color(0xFF6C5CE7),
                        ),
                      );
                    },
                    activeColor: const Color(0xFF6C5CE7),
                  ),
                ),
                ListTile(
                  title: Text(
                    'Orta (192kbps)',
                    style: TextStyle(color: ThemeService.textColor),
                  ),
                  leading: Radio<int>(
                    value: 192,
                    groupValue: selectedQuality,
                    onChanged: (value) {
                      setState(() {
                        selectedQuality = value!;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Müzik kalitesi: ${_getQualityText(selectedQuality)}',
                          ),
                          backgroundColor: const Color(0xFF6C5CE7),
                        ),
                      );
                    },
                    activeColor: const Color(0xFF6C5CE7),
                  ),
                ),
                ListTile(
                  title: Text(
                    'Yüksek (320kbps)',
                    style: TextStyle(color: ThemeService.textColor),
                  ),
                  leading: Radio<int>(
                    value: 320,
                    groupValue: selectedQuality,
                    onChanged: (value) {
                      setState(() {
                        selectedQuality = value!;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Müzik kalitesi: ${_getQualityText(selectedQuality)}',
                          ),
                          backgroundColor: const Color(0xFF6C5CE7),
                        ),
                      );
                    },
                    activeColor: const Color(0xFF6C5CE7),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Color(0xFF6C5CE7)),
                ),
              ),
            ],
          ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: ThemeService.cardColor,
            title: Text(
              'PitonMusic Hakkında',
              style: TextStyle(color: ThemeService.textColor),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PitonMusic v1.0.0',
                  style: TextStyle(
                    color: ThemeService.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Modern müzik dinleme deneyimi için geliştirilmiş cross-platform uygulaması.',
                  style: TextStyle(color: ThemeService.subtitleColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'Özellikler:',
                  style: TextStyle(
                    color: ThemeService.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Jamendo API entegrasyonu\n• Real-time müzik çalma\n• Favori sistem\n• Auto-play\n• Responsive tasarım\n• Tema desteği\n• Kalite ve ses ayarları\n• Offline Dinleme',
                  style: TextStyle(color: ThemeService.subtitleColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Geliştirici: Nazım Furkan Güneş',
                  style: TextStyle(color: ThemeService.subtitleColor),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Tamam',
                  style: TextStyle(color: Color(0xFF6C5CE7)),
                ),
              ),
            ],
          ),
    );
  }

  void _showClearFavoritesDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: ThemeService.cardColor,
            title: Text(
              'Favorileri Temizle',
              style: TextStyle(color: ThemeService.textColor),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tüm favori müzikleri silmek istediğinize emin misiniz?',
                  style: TextStyle(color: ThemeService.subtitleColor),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Color(0xFF6C5CE7)),
                ),
              ),
              TextButton(
                onPressed: () {
                  FavoritesService.clearAllFavorites();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Favoriler başarıyla temizlendi!'),
                      backgroundColor: Color(0xFF6C5CE7),
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text(
                  'Temizle',
                  style: TextStyle(color: Color(0xFF6C5CE7)),
                ),
              ),
            ],
          ),
    );
  }
}
