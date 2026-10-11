import 'package:flutter/material.dart';
import '../network/api_config.dart';

class AppImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 50,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildPlaceholder(context);
    }

    String resolvedUrl = imageUrl;
    if (!imageUrl.startsWith('http') && !imageUrl.startsWith('assets/')) {
      resolvedUrl = '${ApiConfig.baseUrl}${imageUrl.startsWith('/') ? '' : '/'}$imageUrl';
    }

    if (resolvedUrl.startsWith('http')) {
      return Image.network(
        resolvedUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: _buildPlaceholder(context),
          );
        },
      );
    } else {
      return Image.asset(
        resolvedUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
      );
    }
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Image.asset(
      'assets/images/camera.png',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Icon(
            Icons.camera_alt,
            size: iconSize,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
