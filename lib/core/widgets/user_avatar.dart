import 'package:flutter/material.dart';
import 'app_text.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? localImagePath;
  final String? fallbackAsset;
  final String? displayName;
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.localImagePath,
    this.fallbackAsset,
    this.displayName,
    this.radius = 20.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.outline,
        backgroundImage: _getAvatarImage(),
        child: _getFallbackChild(context),
      ),
    );
  }

  ImageProvider? _getAvatarImage() {
    if (localImagePath != null && localImagePath!.isNotEmpty) {
      // Typically FileImage(File(localImagePath!)) - but we stick to AssetImage/NetworkImage for now
      return AssetImage(localImagePath!);
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return NetworkImage(imageUrl!);
    }
    if (fallbackAsset != null && fallbackAsset!.isNotEmpty) {
      return AssetImage(fallbackAsset!);
    }
    return null;
  }

  Widget? _getFallbackChild(BuildContext context) {
    if (_getAvatarImage() != null) return null;

    String initials = '';
    if (displayName != null && displayName!.isNotEmpty) {
      final names = displayName!.trim().split(' ');
      if (names.isNotEmpty) {
        initials = names.first[0].toUpperCase();
        if (names.length > 1) {
          initials += names.last[0].toUpperCase();
        }
      }
    }

    return AppText(
      initials.isNotEmpty ? initials : 'U',
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.bold,
      fontSize: radius * 0.8,
    );
  }
}
