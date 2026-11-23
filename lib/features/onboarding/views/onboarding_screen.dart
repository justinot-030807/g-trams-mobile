import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.badge,
    required this.title,
    required this.body,
    required this.icon,
    required this.assetPath,
  });

  final String badge;
  final String title;
  final String body;
  final IconData icon;
  final String assetPath;
}

/// First-launch 3-slide onboarding experience tailored for Operators & TODA Presidents.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _finishOnboarding() async {
    await ref.read(appPreferencesProvider.notifier).markOnboardingComplete();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final prefs = ref.watch(appPreferencesProvider);
    final strings = AppStrings(prefs.language);

    final slides = [
      _OnboardingSlideData(
        badge: '01 / DIGITAL WALLET',
        title: strings.onboard1Title,
        body: strings.onboard1Body,
        icon: Icons.badge_outlined,
        assetPath: 'assets/images/gasan-logo.png',
      ),
      _OnboardingSlideData(
        badge: '02 / SMART SCANNER',
        title: strings.onboard2Title,
        body: strings.onboard2Body,
        icon: Icons.document_scanner_outlined,
        assetPath: 'assets/images/tricycle-icon-maroon.png',
      ),
      _OnboardingSlideData(
        badge: '03 / TODA & SUPPORT',
        title: strings.onboard3Title,
        body: strings.onboard3Body,
        icon: Icons.groups_2_outlined,
        assetPath: 'assets/images/gtrams-logo.png',
      ),
    ];

    final isLast = _currentPage == slides.length - 1;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: EN/FIL switch + Skip
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => ref
                        .read(appPreferencesProvider.notifier)
                        .toggleLanguage(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            size: 15,
                            color: palette.brandAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            prefs.language == 'fil' ? 'TAGALOG' : 'ENGLISH',
                            style: CivicTheme.monoStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: palette.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(strings.skip),
                  ),
                ],
              ),
            ),

            // Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CivicCard(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            children: [
                              Container(
                                width: 112,
                                height: 112,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: palette.canvas,
                                  border: Border.all(
                                    color: CivicColors.gasanGold
                                        .withValues(alpha: 0.7),
                                    width: 1.5,
                                  ),
                                ),
                                child: Image.asset(
                                  slide.assetPath,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: CivicColors.gasanMaroon
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      slide.icon,
                                      size: 14,
                                      color: palette.brandAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      slide.badge,
                                      style: CivicTheme.monoStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: palette.brandAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: palette.muted,
                                    height: 1.55,
                                  ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom indicator + Primary CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(slides.length, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? CivicColors.gasanMaroon
                              : palette.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  CivicPrimaryButton(
                    label: isLast ? strings.getStarted : strings.next,
                    icon: isLast
                        ? Icons.arrow_forward_rounded
                        : Icons.chevron_right_rounded,
                    onPressed: () {
                      if (isLast) {
                        _finishOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
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
