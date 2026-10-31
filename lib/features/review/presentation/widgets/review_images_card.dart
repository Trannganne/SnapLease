import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/app_image_viewer_dialog.dart';
import '../../../../core/widgets/app_text.dart';

class ReviewImagesCard extends StatelessWidget {
  final List<String> images;
  final ValueChanged<String> onImageAdded;
  final ValueChanged<int> onImageRemoved;
  final int maxImages;
  final bool enabled;

  const ReviewImagesCard({
    super.key,
    required this.images,
    required this.onImageAdded,
    required this.onImageRemoved,
    this.maxImages = 4,
    this.enabled = true,
  });

  Future<void> _pickImage(BuildContext context) async {
    if (!enabled || images.length >= maxImages) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (pickedFile != null) {
        onImageAdded(pickedFile.path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể chọn ảnh: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    }
  }

  void _viewImage(BuildContext context, String imagePath) {
    if (imagePath.startsWith('http') || imagePath.startsWith('assets/')) {
      AppImageViewerDialog.show(
        context: context,
        imageUrl: imagePath,
        title: 'Hình ảnh thực tế',
      );
    } else {
      AppImageViewerDialog.show(
        context: context,
        imagePath: imagePath,
        title: 'Hình ảnh thực tế',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = images.length;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius * 1.5),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSizes.pageMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Hình ảnh thực tế',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppText(
                '$count/$maxImages',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 4),
          AppText(
            'Thêm ảnh thiết bị hoặc ảnh chụp từ thiết bị',
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSizes.spacingM),
          // Thumbnails and Add Box row
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // List of added image thumbnails
              ...images.asMap().entries.map((entry) {
                final index = entry.key;
                final path = entry.value;
                return _buildThumbnail(context, path, index);
              }),
              // Add button (only shown if count < maxImages)
              if (count < maxImages) _buildAddButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, String path, int index) {
    final colors = Theme.of(context).colorScheme;

    Widget imageWidget;
    if (path.startsWith('http') || path.startsWith('assets/')) {
      imageWidget = AppImage(
        imageUrl: path,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
      );
    } else {
      final file = File(path);
      imageWidget =
          file.existsSync()
              ? Image.file(
                file,
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallback(context),
              )
              : _buildFallback(context);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () => _viewImage(context, path),
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              child: imageWidget,
            ),
          ),
        ),
        if (enabled)
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              button: true,
              label: 'Xóa ảnh ${index + 1}',
              child: InkWell(
                onTap: () => onImageRemoved(index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFF595959),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.image_outlined, size: 28),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Thêm ảnh đánh giá',
      child: InkWell(
        onTap: enabled ? () => _pickImage(context) : null,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: colors.outline.withValues(alpha: 0.7),
            strokeWidth: 1.2,
            gap: 4.0,
            dash: 4.0,
            borderRadius: AppSizes.borderRadius,
          ),
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 26,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                AppText(
                  'Thêm ảnh',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double borderRadius;

  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
    required this.dash,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    final path =
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width, size.height),
            Radius.circular(borderRadius),
          ),
        );

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final length = draw ? dash : gap;
        if (draw) {
          dashPath.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      gap != oldDelegate.gap ||
      dash != oldDelegate.dash ||
      borderRadius != oldDelegate.borderRadius;
}
