import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import 'main_navigation_screen.dart';

class GettingStartedScreen extends StatefulWidget {
  const GettingStartedScreen({super.key});

  @override
  State<GettingStartedScreen> createState() => _GettingStartedScreenState();
}

class _GettingStartedScreenState extends State<GettingStartedScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'PitonMusic',
      description:
          'Müziğin büyülü dünyasına adım atın.\nFavori şarkılarınızı keşfedin, çalma listeleri\noluşturun ve müziğin tadını çıkarın.',
      icon: Icons.music_note,
    ),
    OnboardingData(
      title: 'Keşfet',
      description:
          'Onlarca şarkı arasından\nzevkinize uygun olanları bulun.\nYeni sanatçıları ve türleri keşfedin.',
      icon: Icons.explore,
    ),
    OnboardingData(
      title: 'Keyif Al',
      description:
          'Beğendiğiniz şarkıları favorilerinize ekleyin.\nFavori müzik listenizden kolayca dinleyin\nve en sevdiğiniz müziklere hızla ulaşın.',
      icon: Icons.favorite,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeService.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            _buildIndicator(),
            const SizedBox(height: 40),
            _buildNavigationButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF00B4D8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                children: [
                  // Background pattern
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFF00B4D8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // Logo content
                  Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.95),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Stack(
                          children: [
                            if (_currentPage == 0)
                              // İlk sayfa için logo
                              Image.asset(
                                'assets/images/piton_logo.png',
                                fit: BoxFit.cover,
                                width: 140,
                                height: 140,
                                errorBuilder: (context, error, stackTrace) {
                                  return Stack(
                                    children: [
                                      const Center(
                                        child: Text(
                                          'P',
                                          style: TextStyle(
                                            fontSize: 70,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF6C5CE7),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 25,
                                        right: 25,
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFF00B4D8),
                                          ),
                                          child: const Icon(
                                            Icons.music_note,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              )
                            else
                              // Diğer sayfalar için icon
                              Center(
                                child: Icon(
                                  data.icon,
                                  size: 80,
                                  color: const Color(0xFF6C5CE7),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Başlık
          Text(
            data.title,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: ThemeService.textColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: ThemeService.subtitleColor,
              height: 1.5,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                _currentPage == index
                    ? const Color(0xFF6C5CE7)
                    : ThemeService.subtitleColor.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton() {
    return GestureDetector(
      onTap: () {
        if (_currentPage < _pages.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MainNavigationScreen(),
            ),
          );
        }
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF6C5CE7),
        ),
        child: const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
  });
}
