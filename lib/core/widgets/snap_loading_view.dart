import 'package:flutter/material.dart';
import '../constants/app_sizes.dart';
import 'retro_camera_loader.dart';

class SnapLoadingView extends StatelessWidget {
  final String message;
  final String? subtitle;
  final double size;
  final bool showProgress, showAnimatedDots;
  final Widget? footer;
  const SnapLoadingView({
    super.key,
    this.message = 'Đang chuẩn bị thiết bị cho bạn',
    this.subtitle,
    this.size = RetroCameraLoader.medium,
    this.showProgress = true,
    this.showAnimatedDots = true,
    this.footer,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.pageMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RetroCameraLoader(
              message: message,
              subtitle: subtitle,
              size: size,
              showProgress: showProgress,
              showAnimatedDots: showAnimatedDots,
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    ),
  );
}

class SnapButtonLoader extends StatelessWidget {
  const SnapButtonLoader({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 30,
    height: 28,
    child: FittedBox(
      child: RetroCameraLoader(
        size: 30,
        message: '',
        showProgress: false,
        showAnimatedDots: false,
      ),
    ),
  );
}

/// Presentation only: the owner supplies its existing request state and Back guard.
/// Keep this wrapper mounted so the form, focus and controllers survive requests.
class SnapLoadingOverlay extends StatelessWidget {
  final bool loading;
  final String message;
  final Widget child;
  final bool avoidKeyboardInsets;
  final Widget? footer;
  const SnapLoadingOverlay({
    super.key,
    required this.loading,
    required this.message,
    required this.child,
    this.avoidKeyboardInsets = true,
    this.footer,
  });

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      TickerMode(
        enabled: !loading,
        child: ExcludeSemantics(
          excluding: loading,
          child: AbsorbPointer(absorbing: loading, child: child),
        ),
      ),
      if (loading) ...[
        Positioned.fill(
          child: ModalBarrier(
            dismissible: false,
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(
              bottom:
                  avoidKeyboardInsets
                      ? MediaQuery.viewInsetsOf(context).bottom
                      : 0,
            ),
            child: SnapLoadingView(
              message: message,
              size: RetroCameraLoader.large,
              footer: footer,
            ),
          ),
        ),
      ],
    ],
  );
}
