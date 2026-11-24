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
    required this.title,
    required this.body,
    required this.icon,
    this.assetPath,
  });

  final String title;
  final String body;
  final IconData icon;
  final String? assetPath;
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

  Widget _buildSlideEmblem(
    _OnboardingSlideData slide,
    CivicPalette palette,
    bool isDark,
  ) {
    final isBrandSeal = slide.assetPath == 'assets/images/gtrams-logo.png';

    return Container(
      width: 132,
      height: 132,
      padding: EdgeInsets.all(isBrandSeal ? 6 : 22),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.surface,
        border: Border.all(
          color: CivicColors.gasanGold.withValues(alpha: 0.82),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: slide.assetPath != null
          ? ClipOval(
              child: Image.asset(
                slide.assetPath!,
                fit: BoxFit.contain,
              ),
            )
          : Center(
              child: Icon(
                slide.icon,
                size: 52,
                color: palette.brandAccent,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = ref.watch(appPreferencesProvider);
    final strings = AppStrings(prefs.language);

    final slides = [
      _OnboardingSlideData(
        title: strings.onboard1Title,
        body: strings.pick(
          'Track franchise status, view your MTOP E-Copy, and show your LGU QR ID anytime — even offline.',
          'Subaybayan ang prangkisa, tingnan ang MTOP E-Copy, at ipakita ang LGU QR ID kahit offline.',
        ),
        icon: Icons.badge_outlined,
        assetPath: 'assets/images/gtrams-logo.png',
      ),
      _OnboardingSlideData(
        title: strings.pick(
          'Scan Documents & Auto-Fill',
          'I-scan ang Dokumento at Auto-Fill',
        ),
        body: strings.pick(
          'Snap your OR/CR, Driver\'s License, and Cedula for faster OVM — LLSA I verification.',
          'Kunan ang OR/CR, Driver\'s License, at Cedula para mas mabilis ang pagsusuri ng OVM — LLSA I.',
        ),
        icon: Icons.document_scanner_outlined,
        assetPath: isDark
            ? 'assets/images/tricycle-icon-gold.png'
            : 'assets/images/tricycle-icon-maroon.png',
      ),
      _OnboardingSlideData(
        title: strings.onboard3Title,
        body: strings.pick(
          'Manage TODA rosters, receive renewal alerts, and message G-TRAMS Support in real time.',
          'Pamahalaan ang TODA roster, tumanggap ng renewal alert, at mag-chat sa G-TRAMS Support.',
        ),
        icon: Icons.groups_2_outlined,
        assetPath: 'assets/images/gtrams-logo.png',
      ),
    ];

    final isLast = _currentPage == slides.length - 1;
    final activeDotColor =
        isDark ? CivicColors.gasanGold : CivicColors.gasanMaroon;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: EN/FIL switch + Skip
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: palette.surface,
                    shape: StadiumBorder(
                      side: BorderSide(color: palette.border),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => ref
                          .read(appPreferencesProvider.notifier)
                          .toggleLanguage(),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.translate_rounded,
                                size: 16,
                                color: palette.brandAccent,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                prefs.language == 'fil' ? 'TAGALOG' : 'ENGLISH',
                                style: CivicTheme.monoStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: palette.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight - 32)
                                .clamp(0.0, double.infinity),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSlideEmblem(slide, palette, isDark),
                              const SizedBox(height: 32),
                              Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 320),
                                child: Text(
                                  slide.body,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: palette.muted,
                                        height: 1.55,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? activeDotColor : palette.border,
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
