import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import '../theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_fonts.dart';
import 'theme_onboarding_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<Map<String, dynamic>> get _pages => [
    {
      'color': AppTheme.primaryBlue,
      'icon': IconlyLight.scan,
      'title': 'onboarding.title_1'.tr(),
      'description': 'onboarding.desc_1'.tr(),
    },
    {
      'color': const Color(0xFF3F51B5),
      'icon': IconlyBold.paper,
      'title': 'onboarding.title_2'.tr(),
      'description': 'onboarding.desc_2'.tr(),
    },
    {
      'color': const Color(0xFFE91E63),
      'icon': IconlyBold.activity,
      'title': 'onboarding.title_3'.tr(),
      'description': 'onboarding.desc_3'.tr(),
    },
    {
      'color': AppTheme.doubtfulSolid,
      'icon': IconlyLight.discovery,
      'title': 'onboarding.title_4'.tr(),
      'description': 'onboarding.desc_4'.tr(),
    },
  ];

  void _onNext() {
    if (_currentPage == _pages.length - 1) {
      _goToThemeOnboarding();
    } else {
      _pageController.jumpToPage(_currentPage + 1);
    }
  }

  void _goToThemeOnboarding() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ThemeOnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _goToThemeOnboarding,
                child: Text(
                  'onboarding.skip'.tr(),
                  style: AppFonts.primary(
                    context,
                    color: AppTheme.getTextSecondary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: page['color'] as Color,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Icon(
                            page['icon'] as IconData,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 60),
                        Text(
                          page['title'] as String,
                          textAlign: TextAlign.center,
                          style: AppFonts.primary(
                            context,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.getTextPrimary(context),
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page['description'] as String,
                          textAlign: TextAlign.center,
                          style: AppFonts.primary(
                            context,
                            fontSize: 16,
                            height: 1.5,
                            color: AppTheme.getTextSecondary(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppTheme.primaryBlue
                              : AppTheme.getBorderColor(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _onNext,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _currentPage == _pages.length - 1
                            ? IconlyBold.tick_square
                            : IconlyLight.arrow_right_2,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
