import 'package:flutter/material.dart';

/// A shimmer container that animates a soft gradient across its children.
class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const SkeletonShimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.1, 0.3, 0.4],
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0.0, 0.0);
  }
}

/// A basic building block box for shimmer skeletons
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(borderRadius) : null,
      ),
    );
  }
}

/// A pre-styled card placeholder for order lists and general items
class SkeletonCardPlaceholder extends StatelessWidget {
  const SkeletonCardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SkeletonBox(width: 44, height: 44, borderRadius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 120, height: 14, borderRadius: 4),
                SizedBox(height: 8),
                SkeletonBox(width: 180, height: 11, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SkeletonBox(width: 60, height: 20, borderRadius: 6),
        ],
      ),
    );
  }
}

/// A vertical list of skeleton card placeholders
class SkeletonListPlaceholder extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const SkeletonListPlaceholder({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        itemBuilder: (context, index) => const SkeletonCardPlaceholder(),
      ),
    );
  }
}

/// A grid placeholder for product items
class SkeletonGridPlaceholder extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const SkeletonGridPlaceholder({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: GridView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                child: SkeletonBox(
                  width: double.infinity,
                  borderRadius: 10,
                ),
              ),
              SizedBox(height: 10),
              SkeletonBox(width: 100, height: 13, borderRadius: 4),
              SizedBox(height: 6),
              SkeletonBox(width: 60, height: 11, borderRadius: 4),
              SizedBox(height: 8),
              SkeletonBox(width: double.infinity, height: 28, borderRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}
