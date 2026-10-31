import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'app_text.dart';
import 'loading_motion.dart';

class RetroCameraLoader extends StatelessWidget {
  static const double small = 96, medium = 180, large = 240;
  final String message;
  final String? subtitle;
  final double size;
  final bool showProgress, showAnimatedDots;
  const RetroCameraLoader({
    super.key,
    this.message = 'Đang chuẩn bị thiết bị cho bạn',
    this.subtitle,
    this.size = medium,
    this.showProgress = true,
    this.showAnimatedDots = true,
  }) : assert(size > 0);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: [message, if (subtitle != null) subtitle!].join('. '),
      liveRegion: true,
      child: ExcludeSemantics(
        child: LoadingMotion(
          builder: (context, clock, reduced) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: CustomPaint(
                      painter: RetroCameraPainter(
                        progress:
                            reduced ? const AlwaysStoppedAnimation(0.3) : clock,
                        primary: colors.primary,
                        ink: colors.onSurface,
                        cream: AppColors.loadingCream,
                      ),
                    ),
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.spacingS),
                  AppText(
                    message,
                    textAlign: TextAlign.center,
                    fontWeight: FontWeight.w600,
                  ),
                ],
                if (subtitle != null) ...[
                  const SizedBox(height: AppSizes.spacingS),
                  AppText(
                    subtitle!,
                    textAlign: TextAlign.center,
                    color: colors.onSurfaceVariant,
                  ),
                ],
                if (showAnimatedDots)
                  SizedBox(
                    height: 20,
                    width: 44,
                    child: CustomPaint(
                      painter: _DotsPainter(
                        reduced ? const AlwaysStoppedAnimation(0) : clock,
                        colors.primary,
                      ),
                    ),
                  ),
                if (showProgress) ...[
                  const SizedBox(height: AppSizes.spacingS),
                  SizedBox(
                    width: size,
                    height: 3,
                    child:
                        reduced
                            ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: .25),
                              ),
                            )
                            : CustomPaint(
                              painter: _ProgressPainter(clock, colors.primary),
                            ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// All geometry uses a 240 × 240 canvas; each mechanical part has its own motion.
class RetroCameraPainter extends CustomPainter {
  final Animation<double> progress;
  final Color primary, ink, cream;
  RetroCameraPainter({
    required this.progress,
    required this.primary,
    required this.ink,
    required this.cream,
  }) : super(repaint: progress);

  double ramp(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value * 3000;
    final wind = ramp(t, 0, 600);
    final focus = ramp(t, 600, 1200);
    final snap = ramp(t, 1200, 1600);
    final print = Curves.easeInOut.transform(ramp(t, 1600, 2500));
    final reset = Curves.easeInOut.transform(ramp(t, 2500, 3000));
    final recoil = math.sin(snap * math.pi * 2) * (1 - snap);
    final dark = ink.computeLuminance() > .5;
    // Optical glass and metal stay dark in both themes; onSurface is not glass.
    final metal = Color.lerp(AppColorsLight.textPrimary, primary, .12)!;
    final glass = Color.lerp(Colors.black, primary, .12)!;
    final silver = Color.lerp(cream, Colors.white, .72)!;
    final body = const Rect.fromLTWH(33, 68, 174, 94);
    const center = Offset(120, 115);
    canvas.save();
    canvas.scale(size.width / 240, size.height / 240);

    void box(Rect rect, double radius, Color color) => canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = color,
    );
    void circle(Offset point, double radius, Color color) =>
        canvas.drawCircle(point, radius, Paint()..color = color);
    void ring(Offset point, double radius, Color color, double width) =>
        canvas.drawCircle(
          point,
          radius,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = width,
        );
    void gradientCircle(Offset point, double radius, Gradient gradient) =>
        canvas.drawCircle(
          point,
          radius,
          Paint()
            ..shader = gradient.createShader(
              Rect.fromCircle(center: point, radius: radius),
            ),
        );

    // Static radial falloffs avoid blurred full-screen layers on each frame.
    gradientCircle(
      const Offset(120, 133),
      103,
      RadialGradient(
        colors: [
          primary.withValues(alpha: dark ? .17 : .11),
          primary.withValues(alpha: 0),
        ],
        stops: const [.12, 1],
      ),
    );
    for (final radius in [78.0, 96.0]) {
      ring(
        const Offset(120, 139),
        radius,
        primary.withValues(alpha: dark ? .14 : .07),
        .7,
      );
    }
    canvas.save();
    canvas.translate(120, 207);
    canvas.scale(1, .12);
    gradientCircle(
      Offset.zero,
      78,
      RadialGradient(
        colors: [
          metal.withValues(alpha: dark ? .55 : .2),
          metal.withValues(alpha: 0),
        ],
      ),
    );
    canvas.restore();

    canvas.translate(120, 116 - 4 * math.sin(wind * math.pi) - recoil * 3);
    canvas.rotate(
      .045 * math.sin(wind * math.pi * 2) -
          .028 * math.sin(focus * math.pi) +
          recoil * .03,
    );
    canvas.scale(1 + .02 * math.sin(focus * math.pi));
    canvas.translate(-120, -116);

    final extension = print * (1 - reset);
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(72, 159, 100, 61));
    canvas.translate(120, 159 + extension * 57);
    canvas.rotate(.045 * extension);
    box(const Rect.fromLTWH(-34, -57, 68, 57), 3, silver);
    box(
      const Rect.fromLTWH(-28, -52, 56, 38),
      2,
      Color.lerp(silver, primary, extension * .65)!,
    );
    circle(const Offset(13, -42), 4, cream.withValues(alpha: extension));
    final mountains =
        Path()
          ..moveTo(-28, -14)
          ..lineTo(-10, -37)
          ..lineTo(3, -23)
          ..lineTo(13, -31)
          ..lineTo(28, -14)
          ..close();
    canvas.drawPath(
      mountains,
      Paint()..color = metal.withValues(alpha: .6 * extension),
    );
    canvas.restore();

    // Back shell, bevel and leather face are separate layers.
    final shell = RRect.fromRectAndRadius(body, const Radius.circular(17));
    canvas.drawShadow(
      Path()..addRRect(shell),
      Colors.black.withValues(alpha: .38),
      9,
      true,
    );
    canvas.drawRRect(
      shell,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [silver, Color.lerp(primary, metal, .65)!, metal],
          stops: const [0, .45, 1],
        ).createShader(body),
    );
    final face = RRect.fromRectAndRadius(
      body.deflate(3),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(primary, Colors.white, .15)!,
            primary,
            Color.lerp(primary, metal, .42)!,
          ],
        ).createShader(body),
    );
    canvas.save();
    canvas.clipRRect(face);
    // Brushed top plate; cream is a restrained accent rather than half the body.
    canvas.drawRect(
      const Rect.fromLTWH(36, 71, 168, 23),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [silver, Color.lerp(silver, primary, dark ? .6 : .22)!],
        ).createShader(const Rect.fromLTWH(36, 71, 168, 23)),
    );
    for (var y = 100.0; y < 155; y += 5) {
      for (var x = 42.0; x < 200; x += 5) {
        circle(Offset(x, y), .55, metal.withValues(alpha: .27));
      }
    }
    canvas.drawLine(
      const Offset(38, 94),
      const Offset(202, 94),
      Paint()
        ..color = metal.withValues(alpha: .4)
        ..strokeWidth = 1,
    );
    canvas.restore();
    canvas.drawRRect(
      face,
      Paint()
        ..color = silver.withValues(alpha: .32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    // Grip and viewfinder.
    box(const Rect.fromLTWH(41, 100, 16, 43), 4, metal.withValues(alpha: .3));
    box(const Rect.fromLTWH(43, 102, 12, 10), 2, metal);
    box(const Rect.fromLTWH(45, 104, 8, 5), 1, primary.withValues(alpha: .8));
    box(const Rect.fromLTWH(139, 77, 25, 10), 3, metal);
    box(const Rect.fromLTWH(142, 79, 19, 5), 1, silver.withValues(alpha: .45));
    box(const Rect.fromLTWH(177, 77, 16, 12), 2, cream);
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(180 + i * 3, 79),
        Offset(180 + i * 3, 87),
        Paint()
          ..color = metal.withValues(alpha: .22)
          ..strokeWidth = .6,
      );
    }
    // Distinct shutter button and wind-up lever above the top plate.
    box(const Rect.fromLTWH(61, 60, 23, 8), 3, metal);
    box(const Rect.fromLTWH(63, 57, 19, 6), 3, silver);
    box(
      const Rect.fromLTWH(65, 57, 15, 2),
      1,
      Colors.white.withValues(alpha: .8),
    );
    canvas.save();
    canvas.translate(52, 66);
    canvas.rotate(-.9 * math.sin(wind * math.pi));
    box(const Rect.fromLTWH(-13, -4, 28, 4), 2, metal);
    box(const Rect.fromLTWH(-13, -5, 28, 2), 1, silver);
    circle(const Offset(-13, -3), 4, metal);
    circle(const Offset(-13, -4), 2, silver);
    canvas.restore();
    // Small cog below the grip remains mechanically animated.
    canvas.save();
    canvas.translate(49, 137);
    canvas.rotate(wind * math.pi * 2);
    circle(Offset.zero, 5, silver.withValues(alpha: .8));
    for (var i = 0; i < 8; i++) {
      canvas.rotate(math.pi / 4);
      box(
        const Rect.fromLTWH(-.7, -7, 1.4, 3),
        .4,
        silver.withValues(alpha: .8),
      );
    }
    circle(Offset.zero, 2, metal);
    canvas.restore();
    // Print slot and its raised lower lip.
    box(const Rect.fromLTWH(77, 155, 86, 6), 3, silver.withValues(alpha: .65));
    box(const Rect.fromLTWH(80, 157, 80, 3), 1.5, glass);

    final lens = 43 + 2 * math.sin(focus * math.pi);
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: lens)),
      Colors.black.withValues(alpha: .65),
      5,
      true,
    );
    gradientCircle(
      center,
      lens,
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [silver, metal, silver.withValues(alpha: .85), metal],
        stops: const [0, .42, .7, 1],
      ),
    );
    gradientCircle(
      center,
      lens - 3,
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(metal, Colors.white, .22)!, glass, metal],
      ),
    );
    ring(center, lens - 5, silver.withValues(alpha: .45), .8);
    // Focus knurling rotates, while the housing and glass keep their own depth.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(focus * math.pi * .8 * (1 - reset));
    for (var i = 0; i < 40; i++) {
      canvas.rotate(math.pi / 20);
      box(
        Rect.fromLTWH(-.45, -lens + 6, .9, 3),
        .2,
        silver.withValues(alpha: i % 5 == 0 ? .65 : .23),
      );
    }
    canvas.restore();
    circle(center, lens - 11, glass);
    ring(center, lens - 11, primary.withValues(alpha: .95), 2);
    ring(center, lens - 14, silver.withValues(alpha: .24), .8);
    gradientCircle(
      center,
      lens - 15,
      RadialGradient(
        center: const Alignment(-.25, -.3),
        radius: .9,
        colors: [Color.lerp(glass, primary, .38)!, glass, Colors.black],
        stops: const [0, .65, 1],
      ),
    );
    // Dark iris blades close around a deep glass pupil during Snap.
    final close = math.sin(snap * math.pi);
    final aperture = 19 * (1 - .9 * close);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (var i = 0; i < 6; i++) {
      canvas.rotate(math.pi / 3);
      final blade =
          Path()
            ..moveTo(aperture, 0)
            ..lineTo(23, -13)
            ..lineTo(23, 13)
            ..close();
      canvas.drawPath(
        blade,
        Paint()..color = Color.lerp(glass, metal, .4 + .3 * close)!,
      );
      canvas.drawPath(
        blade,
        Paint()
          ..color = silver.withValues(alpha: .07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .5,
      );
    }
    canvas.restore();
    gradientCircle(
      center,
      aperture,
      RadialGradient(
        colors: [Color.lerp(glass, primary, .22)!, glass, Colors.black],
      ),
    );
    // Soft optical arcs and small glints; never a white lens core in dark mode.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: lens - 18),
      math.pi * 1.08,
      .8,
      false,
      Paint()
        ..color = silver.withValues(alpha: .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: lens - 20),
      .15,
      .65,
      false,
      Paint()
        ..color = primary.withValues(alpha: .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    gradientCircle(
      const Offset(113, 107),
      7,
      RadialGradient(
        colors: [silver.withValues(alpha: .26), silver.withValues(alpha: 0)],
      ),
    );
    circle(const Offset(115, 110), 2.3, silver.withValues(alpha: .72));
    circle(const Offset(123, 118), 1.1, primary.withValues(alpha: .8));

    final bracketAlpha = math.sin(focus * math.pi);
    final distance = 54 - 6 * focus;
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * math.pi / 2);
      canvas.drawPath(
        Path()
          ..moveTo(-distance, -distance + 6)
          ..lineTo(-distance, -distance)
          ..lineTo(-distance + 6, -distance),
        Paint()
          ..color = primary.withValues(alpha: bracketAlpha * .3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.restore();
    }
    if (t > 1260 && t < 1380) {
      final glow = math.sin((t - 1260) / 120 * math.pi);
      gradientCircle(
        const Offset(185, 83),
        15,
        RadialGradient(
          colors: [
            cream.withValues(alpha: .65 * glow),
            cream.withValues(alpha: 0),
          ],
        ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RetroCameraPainter old) =>
      old.progress != progress ||
      old.primary != primary ||
      old.ink != ink ||
      old.cream != cream;
}

class _DotsPainter extends CustomPainter {
  final Animation<double> clock;
  final Color color;
  _DotsPainter(this.clock, this.color) : super(repaint: clock);
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final wave = (math.sin(clock.value * math.pi * 6 - i * .8) + 1) / 2;
      canvas.drawCircle(
        Offset(10 + i * 12, 10),
        2.5,
        Paint()..color = color.withValues(alpha: .3 + .7 * wave),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) =>
      old.clock != clock || old.color != color;
}

/// Compact refresh feedback with the same lifecycle/reduced-motion behavior.
class SnapLoadingProgress extends StatelessWidget {
  final String label;
  const SnapLoadingProgress({super.key, required this.label});
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    liveRegion: true,
    child: ExcludeSemantics(
      child: LoadingMotion(
        builder: (context, clock, reduced) {
          final color = Theme.of(context).colorScheme.primary;
          return SizedBox(
            height: 3,
            width: double.infinity,
            child:
                reduced
                    ? ColoredBox(color: color.withValues(alpha: .25))
                    : CustomPaint(painter: _ProgressPainter(clock, color)),
          );
        },
      ),
    ),
  );
}

class _ProgressPainter extends CustomPainter {
  final Animation<double> clock;
  final Color color;
  _ProgressPainter(this.clock, this.color) : super(repaint: clock);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)));
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: .15));
    final x = (clock.value * 3 % 1) * 1.4 - .4;
    canvas.drawRect(
      Rect.fromLTWH(x * size.width, 0, size.width * .4, size.height),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter old) =>
      old.clock != clock || old.color != color;
}
