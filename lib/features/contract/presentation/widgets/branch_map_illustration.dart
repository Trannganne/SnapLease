import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_text.dart';

/// Decorative streets only: no coordinates, marker or geographic claim.
/// The real API address is rendered separately by the caller.
class BranchMapIllustration extends StatelessWidget {
  const BranchMapIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Bản đồ minh họa, không biểu thị vị trí chính xác',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        child: SizedBox(
          height: 110,
          width: double.infinity,
          child: CustomPaint(
            painter: _MapPainter(colors),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 18, color: colors.primary),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: AppText('Bản đồ minh họa', fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final ColorScheme colors;
  _MapPainter(this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colors.surfaceContainerHighest,
    );
    final block = Paint()..color = colors.primary.withValues(alpha: 0.055);
    for (var column = 0; column < 6; column++) {
      for (var row = 0; row < 3; row++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              column * size.width / 6 + 6,
              row * 42.0 + 6,
              size.width / 6 - 12,
              28,
            ),
            const Radius.circular(5),
          ),
          block,
        );
      }
    }
    final road =
        Paint()
          ..color = colors.surface
          ..strokeWidth = 9;
    canvas.drawLine(
      Offset(-10, size.height * .8),
      Offset(size.width + 10, size.height * .2),
      road,
    );
    canvas.drawLine(
      Offset(size.width * .23, -10),
      Offset(size.width * .64, size.height + 10),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
