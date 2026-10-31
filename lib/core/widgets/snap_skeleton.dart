import 'package:flutter/material.dart';
import '../constants/app_sizes.dart';
import 'loading_motion.dart';

/// Wrap the whole list/grid, never each card: one shimmer clock per region.
class SnapSkeleton extends StatelessWidget {
  final Widget child;
  final String label;
  const SnapSkeleton({super.key, required this.child, required this.label});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: ExcludeFocus(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: LoadingMotion(
                duration: const Duration(milliseconds: 1600),
                builder:
                    (context, clock, reduced) =>
                        reduced
                            ? child
                            : AnimatedBuilder(
                              animation: clock,
                              child: child,
                              builder:
                                  (context, child) => ShaderMask(
                                    blendMode: BlendMode.srcATop,
                                    shaderCallback:
                                        (rect) => LinearGradient(
                                          begin: Alignment(
                                            -3 + clock.value * 6,
                                            0,
                                          ),
                                          end: Alignment(
                                            -1 + clock.value * 6,
                                            0,
                                          ),
                                          colors: [
                                            colors.surfaceContainerHighest
                                                .withValues(alpha: 0),
                                            colors.surface.withValues(
                                              alpha: .8,
                                            ),
                                            colors.surfaceContainerHighest
                                                .withValues(alpha: 0),
                                          ],
                                        ).createShader(rect),
                                    child: child,
                                  ),
                            ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height, radius;
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppSizes.borderRadius,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
