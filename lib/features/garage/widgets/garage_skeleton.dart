import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Warm-paper loading skeleton for the Operator Garage Dashboard.
class GarageSkeletonList extends StatefulWidget {
  const GarageSkeletonList({super.key, this.cardCount = 2});

  final int cardCount;

  @override
  State<GarageSkeletonList> createState() => _GarageSkeletonListState();
}

class _GarageSkeletonListState extends State<GarageSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final blockColor = Color.lerp(
          palette.border.withValues(alpha: 0.55),
          palette.border.withValues(alpha: 0.95),
          _controller.value,
        )!;

        return Column(
          children: List.generate(widget.cardCount, (idx) {
            return Padding(
              padding: EdgeInsets.only(bottom: idx == widget.cardCount - 1 ? 0 : 14),
              child: CivicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SkeletonBar(width: 110, height: 22, color: blockColor),
                        _SkeletonBar(width: 82, height: 22, color: blockColor),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SkeletonBar(
                      width: double.infinity,
                      height: 76,
                      radius: 10,
                      color: blockColor,
                    ),
                    const SizedBox(height: 12),
                    _SkeletonBar(
                      width: double.infinity,
                      height: 68,
                      radius: 10,
                      color: blockColor,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _SkeletonBar(width: 116, height: 40, radius: 10, color: blockColor),
                        const SizedBox(width: 8),
                        _SkeletonBar(width: 96, height: 40, radius: 10, color: blockColor),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 6,
  });

  final double width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
