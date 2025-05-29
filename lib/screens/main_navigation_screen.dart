import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/audio_player_service.dart';
import '../widgets/mini_player_bar.dart';
import 'explore_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ThemeService.themeStream,
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: ThemeService.backgroundColor,
          body: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: const [
                    ExploreScreenContent(),
                    LibraryScreenContent(),
                    ProfileScreenContent(),
                  ],
                ),
              ),

              // Mini player (if playing) - Navigation bar'ın hemen üstünde
              StreamBuilder<bool>(
                stream: AudioPlayerService.playingStream,
                builder: (context, snapshot) {
                  final hasMusic = AudioPlayerService.currentMusic != null;
                  if (hasMusic) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: MiniPlayerBar(
                        currentIndex: AudioPlayerService.currentIndex ?? 0,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Bottom Navigation Bar
              Container(
                height: 80 + MediaQuery.of(context).padding.bottom,
                decoration: BoxDecoration(
                  color: ThemeService.cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(0, Icons.home, 'Discover'),
                      _buildNavItem(1, Icons.library_books_outlined, 'Library'),
                      _buildNavItem(2, Icons.person_outline, 'Profile'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color:
              isSelected
                  ? const Color(0xFF6C5CE7).withValues(alpha: 0.1)
                  : Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF6C5CE7) : Colors.grey,
                size: isSelected ? 26 : 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF6C5CE7) : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
