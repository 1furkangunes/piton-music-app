import 'package:flutter/material.dart';
import 'dart:async';
import '../models/music.dart';
import '../widgets/music_card.dart';
import '../utils/responsive.dart';
import '../services/jamendo_service.dart';
import '../services/audio_player_service.dart';
import '../services/theme_service.dart';
import '../services/connectivity_service.dart';
import 'now_playing_screen.dart';
import 'main_navigation_screen.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNavigationScreen(initialIndex: 0);
  }
}

class ExploreScreenContent extends StatefulWidget {
  const ExploreScreenContent({super.key});

  @override
  State<ExploreScreenContent> createState() => _ExploreScreenContentState();
}

class _ExploreScreenContentState extends State<ExploreScreenContent> {
  String selectedCategory = 'All';
  final List<String> categories = ['All', 'Rock', 'Pop', 'Electronic', 'Jazz'];

  final JamendoService _jamendoService = JamendoService();
  List<Music> musics = [];
  bool isLoading = true;
  bool isConnected = true;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _connectivityCheckTimer;
  List<Music> get filteredMusics {
    return musics;
  }

  @override
  void initState() {
    super.initState();
    isConnected = ConnectivityService.isConnected;

    _searchController.addListener(() {
      setState(() {});

      _searchTimer?.cancel();
      _searchTimer = Timer(const Duration(milliseconds: 500), () {
        if (_searchController.text.trim().isNotEmpty) {
          _performSearch(_searchController.text.trim());
        } else {
          _loadFeaturedMusic();
        }
      });
    });

    _connectivitySubscription = ConnectivityService.connectivityStream.listen((
      connected,
    ) {
      if (mounted) {
        setState(() {
          isConnected = connected;
        });

        if (connected) {
          _loadFeaturedMusic();
          if (mounted && context.mounted) {
            ConnectivityService.showConnectivitySnackBar(context);
          }
        } else {
          if (mounted && context.mounted) {
            ConnectivityService.showConnectivitySnackBar(context);
          }
          _startPeriodicConnectivityCheck();
        }
      }
    });

    _loadFeaturedMusic();

    _startPeriodicConnectivityCheck();
  }

  void _startPeriodicConnectivityCheck() {
    _connectivityCheckTimer?.cancel();
    _connectivityCheckTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      debugPrint('🔄 Periodic connectivity check...');
      await ConnectivityService.checkConnection();
      final newConnectionStatus = ConnectivityService.isConnected;

      if (newConnectionStatus != isConnected && mounted) {
        debugPrint(
          '📡 Connection status changed: $isConnected -> $newConnectionStatus',
        );
        setState(() {
          isConnected = newConnectionStatus;
        });

        if (newConnectionStatus) {
          debugPrint('✅ Internet connection restored!');
          await _loadFeaturedMusic();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.wifi, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text(
                      'İnternet bağlantısı geri geldi!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          debugPrint('❌ Internet connection lost!');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text(
                      'İnternet bağlantısı kesildi',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange.shade600,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel(); // Timer'ı temizle
    _connectivityCheckTimer?.cancel(); // Connectivity check timer'ını temizle
    _searchController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFeaturedMusic() async {
    debugPrint('🔄 _loadFeaturedMusic called');
    debugPrint('🌐 Connectivity status: ${ConnectivityService.isConnected}');

    // İnternet bağlantısı gerekli
    if (!ConnectivityService.isConnected) {
      debugPrint('❌ No internet connection, skipping music load');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);
    debugPrint('🔄 Starting music loading process...');

    try {
      List<Music> allMusics = [];

      debugPrint('🎵 Calling getAllGenresParallel...');
      allMusics = await _jamendoService.getAllGenresParallel(limitPerGenre: 10);
      debugPrint('🎵 Received ${allMusics.length} tracks from API');

      final uniqueMusics = <String, Music>{};
      for (var music in allMusics) {
        uniqueMusics[music.id] = music;
      }

      final shuffledList = uniqueMusics.values.toList();
      shuffledList.shuffle();

      final finalList = shuffledList.take(50).toList();
      debugPrint('🎵 Final music list: ${finalList.length} tracks');

      if (!mounted) return;
      setState(() {
        musics = finalList;
        isLoading = false;
      });

      debugPrint('✅ Music loading completed successfully');
    } catch (e) {
      debugPrint('❌ Error loading music: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _searchMusic(String query) async {
    if (query.trim().isEmpty) {
      _loadFeaturedMusic();
      return;
    }

    // İnternet bağlantısı kontrolü
    if (!ConnectivityService.requiresInternet(
      context: context,
      message: 'Arama yapmak için internet bağlantısı gerekli',
    )) {
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final searchResults = await _jamendoService.searchTracks(
        query,
        limit: 30,
      );

      if (!mounted) return;
      setState(() {
        musics = searchResults;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error searching music: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadMusicByCategory(String category) async {
    debugPrint('🏷️ Loading music for category: $category');

    if (category == 'All') {
      _loadFeaturedMusic();
      return;
    }

    // İnternet bağlantısı kontrolü
    if (!ConnectivityService.requiresInternet(
      context: context,
      message: 'Kategori müziklerini yüklemek için internet bağlantısı gerekli',
    )) {
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      debugPrint('🎵 Fetching category music for: $category');
      final categoryMusic = await _jamendoService.getTracksByGenre(
        category,
        limit: 30,
      );

      debugPrint('🎵 Category music received: ${categoryMusic.length}');

      // İlk birkaç müziğin genre'ını log'la
      if (categoryMusic.isNotEmpty) {
        for (
          int i = 0;
          i < (categoryMusic.length > 3 ? 3 : categoryMusic.length);
          i++
        ) {
          debugPrint(
            '🎵 Sample music $i: ${categoryMusic[i].title} | Genre: "${categoryMusic[i].genre}"',
          );
        }
      }

      if (!mounted) return;
      setState(() {
        musics = categoryMusic;
        isLoading = false;
      });

      debugPrint('✅ Category loading completed for $category');
    } catch (e) {
      debugPrint('❌ Error loading category music: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void _performSearch(String query) {
    _searchMusic(query);
  }

  void _selectCategory(String category) {
    if (!mounted) return;
    setState(() {
      selectedCategory = category;
    });
    _loadMusicByCategory(category);
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
                    // Offline Indicator
                    if (!isConnected)
                      ConnectivityService.buildOfflineIndicator(),

                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.menu,
                            color: ThemeService.textColor,
                            size: 24,
                          ),
                          Row(
                            children: [
                              Text(
                                'PitonMusic',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeService.textColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.notifications_outlined,
                            color: ThemeService.textColor,
                            size: 24,
                          ),
                        ],
                      ),
                    ),

                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: ThemeService.cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          enabled: isConnected, // Offline'da disable et
                          style: TextStyle(color: ThemeService.textColor),
                          decoration: InputDecoration(
                            hintText:
                                isConnected
                                    ? 'Müzik, sanatçı veya albüm ara...'
                                    : 'Arama için internet bağlantısı gerekli',
                            hintStyle: TextStyle(
                              color: ThemeService.subtitleColor,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color:
                                  isConnected
                                      ? ThemeService.subtitleColor
                                      : ThemeService.subtitleColor.withValues(
                                        alpha: 0.5,
                                      ),
                            ),
                            suffixIcon:
                                _searchController.text.isNotEmpty
                                    ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: ThemeService.subtitleColor,
                                      ),
                                      onPressed: () {
                                        _searchTimer
                                            ?.cancel(); // Timer'ı cancel et
                                        _searchController.clear();
                                        _loadFeaturedMusic();
                                      },
                                    )
                                    : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Categories
                    if (isConnected)
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final isSelected = selectedCategory == category;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _selectCategory(category),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? const Color(0xFF6C5CE7)
                                            : ThemeService.cardColor,
                                    borderRadius: BorderRadius.circular(20),
                                    border:
                                        isSelected
                                            ? null
                                            : Border.all(
                                              color: ThemeService.subtitleColor
                                                  .withValues(alpha: 0.3),
                                            ),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : ThemeService.textColor,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // Title
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isConnected
                              ? 'Trending'
                              : 'İnternet Bağlantısı Gerekli',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ThemeService.textColor,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Music Grid or Offline Message
                    Expanded(
                      child:
                          !isConnected
                              ? RefreshIndicator(
                                onRefresh: () async {
                                  // Internet durumunu kontrol et
                                  await ConnectivityService.checkConnection();
                                  if (ConnectivityService.isConnected) {
                                    setState(() {
                                      isConnected = true;
                                    });
                                    await _loadFeaturedMusic();
                                  }
                                },
                                child: SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.6,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.wifi_off,
                                            size: 80,
                                            color: ThemeService.subtitleColor
                                                .withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'İnternet bağlantısı yok',
                                            style: TextStyle(
                                              color: ThemeService.subtitleColor,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'İndirilen müziklerinizi dinleyebilirsiniz',
                                            style: TextStyle(
                                              color: ThemeService.subtitleColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const SizedBox(height: 24),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: () async {
                                                  await ConnectivityService.checkConnection();

                                                  if (ConnectivityService
                                                      .isConnected) {
                                                    setState(() {
                                                      isConnected = true;
                                                    });
                                                    await _loadFeaturedMusic();
                                                  }
                                                },
                                                icon: const Icon(Icons.refresh),
                                                label: const Text('Yenile'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.orange.shade600,
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 10,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.pushNamed(
                                                    context,
                                                    '/downloads',
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.download_done,
                                                ),
                                                label: const Text(
                                                  'İndirilenler',
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF6C5CE7,
                                                  ),
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 10,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              : isLoading
                              ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF6C5CE7),
                                ),
                              )
                              : filteredMusics.isEmpty
                              ? Center(
                                child: Text(
                                  'Müzik bulunamadı',
                                  style: TextStyle(
                                    color: ThemeService.subtitleColor,
                                    fontSize: 18,
                                  ),
                                ),
                              )
                              : GridView.builder(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  bottom: 100, // Bottom padding for mini player
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount:
                                          ResponsiveHelper.getGridCrossAxisCount(
                                            context,
                                          ),
                                      childAspectRatio:
                                          ResponsiveHelper.getCardAspectRatio(
                                            context,
                                          ),
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                itemCount: filteredMusics.length,
                                itemBuilder: (context, index) {
                                  return MusicCard(
                                    music: filteredMusics[index],
                                    onTap: () async {
                                      // Play music and navigate immediately
                                      try {
                                        // Start playing music with playlist info
                                        AudioPlayerService.playMusic(
                                          filteredMusics[index],
                                          playlist: filteredMusics,
                                          index: index,
                                        );

                                        // Navigate to Now Playing immediately
                                        if (context.mounted) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => NowPlayingScreen(
                                                    music:
                                                        filteredMusics[index],
                                                    playlist: filteredMusics,
                                                    currentIndex: index,
                                                  ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        // Error playing music, but don't show debug logs
                                      }
                                    },
                                  );
                                },
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
}
