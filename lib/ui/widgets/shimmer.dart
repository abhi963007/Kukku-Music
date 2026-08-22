import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A lightweight shimmer sweep used for skeleton placeholders.
///
/// Implemented locally rather than pulling in a package: it is a single
/// [AnimatedBuilder] driving a [LinearGradient] through a [ShaderMask].
class Shimmer extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const Shimmer({super.key, required this.child, this.enabled = true});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final slide = (_controller.value * 2) - 0.5;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0x00FFFFFF),
                Color(0x1FFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [
                (slide - 0.3).clamp(0.0, 1.0),
                slide.clamp(0.0, 1.0),
                (slide + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A neutral filled block used to compose skeletons.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    BorderRadius? borderRadius,
  }) : borderRadius = borderRadius ?? const BorderRadius.all(Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Circular skeleton, for artist avatars.
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLight,
        shape: BoxShape.circle,
      ),
    );
  }
}
