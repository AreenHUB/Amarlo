// lib/widgets/skeletons.dart
import 'package:flutter/material.dart';

/// مستطيل shimmer للـ loading placeholder
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  final bool circle;

  const _ShimmerBox({
    this.width = double.infinity,
    this.height = 16,
    this.radius = 8,
    this.circle = false,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          width: widget.circle ? widget.height : widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.circle
                ? null
                : BorderRadius.circular(widget.radius),
            shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: const [
                Color(0xFFEEEEEE),
                Color(0xFFF5F5F5),
                Color(0xFFEEEEEE),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Public helpers ────────────────────────────
Widget skeletonBox({
  double width = double.infinity,
  double height = 16,
  double radius = 8,
}) =>
    _ShimmerBox(width: width, height: height, radius: radius);

Widget skeletonCircle(double size) =>
    _ShimmerBox(height: size, circle: true);

// ══════════════════════════════════════════════
//  Service Card Skeleton
// ══════════════════════════════════════════════
class ServiceCardSkeleton extends StatelessWidget {
  const ServiceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            skeletonBox(height: 130, radius: 0),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  skeletonBox(height: 14, width: 120),
                  const SizedBox(height: 6),
                  skeletonBox(height: 12, width: 80),
                  const SizedBox(height: 6),
                  skeletonBox(height: 12, width: 50),
                  const SizedBox(height: 10),
                  skeletonBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  List Item Skeleton
// ══════════════════════════════════════════════
class ListItemSkeleton extends StatelessWidget {
  const ListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            skeletonCircle(44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  skeletonBox(height: 14, width: 140),
                  const SizedBox(height: 8),
                  skeletonBox(height: 12, width: 100),
                  const SizedBox(height: 6),
                  skeletonBox(height: 12, width: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  Profile Header Skeleton
// ══════════════════════════════════════════════
class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          skeletonCircle(90),
          const SizedBox(height: 12),
          skeletonBox(height: 18, width: 140),
          const SizedBox(height: 8),
          skeletonBox(height: 14, width: 100),
          const SizedBox(height: 20),
          skeletonBox(height: 80),
          const SizedBox(height: 12),
          skeletonBox(height: 80),
          const SizedBox(height: 12),
          skeletonBox(height: 80),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  Post Card Skeleton
// ══════════════════════════════════════════════
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            skeletonBox(height: 16, width: 160),
            const SizedBox(height: 8),
            skeletonBox(height: 12),
            const SizedBox(height: 4),
            skeletonBox(height: 12, width: 200),
            const SizedBox(height: 10),
            skeletonBox(height: 12, width: 80),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  Page-level skeleton (list of items)
// ══════════════════════════════════════════════
class PageSkeleton extends StatelessWidget {
  final Widget Function() itemBuilder;
  final int count;

  const PageSkeleton({
    super.key,
    required this.itemBuilder,
    this.count = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: count,
      itemBuilder: (_, __) => itemBuilder(),
    );
  }
}
