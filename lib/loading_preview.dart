import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/retro_camera_loader.dart';
import 'core/widgets/snap_loading_view.dart';

void main() {
  if (!kDebugMode) throw UnsupportedError('Loading preview is debug only');
  runApp(const LoadingPreview());
}

class LoadingPreview extends StatefulWidget {
  const LoadingPreview({super.key});
  static const mobileSize = Size(390, 844);
  @override
  State<LoadingPreview> createState() => _LoadingPreviewState();
}

class _LoadingPreviewState extends State<LoadingPreview> {
  bool dark = false, reduced = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    home: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final controls = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'SNAPLEASE · Loading preview\n390 × 844 · chu kỳ 3 giây',
              ),
            ),
            SwitchListTile(
              title: const Text('Dark theme'),
              value: dark,
              activeThumbColor: colors.primary,
              onChanged: (value) => setState(() => dark = value),
            ),
            SwitchListTile(
              title: const Text('Reduced motion'),
              value: reduced,
              activeThumbColor: colors.primary,
              onChanged: (value) => setState(() => reduced = value),
            ),
          ],
        );
        final stage = Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FittedBox(
              fit: BoxFit.contain,
              child: RepaintBoundary(
                key: const ValueKey('loading-mobile-canvas'),
                child: SizedBox(
                  width: LoadingPreview.mobileSize.width,
                  height: LoadingPreview.mobileSize.height,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: LoadingPreview.mobileSize,
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                      viewInsets: EdgeInsets.zero,
                      disableAnimations:
                          reduced || MediaQuery.disableAnimationsOf(context),
                    ),
                    child: ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: const SnapLoadingView(
                        size: RetroCameraLoader.large,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 760) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 250, child: controls),
                      Expanded(child: stage),
                    ],
                  );
                }
                return Column(children: [controls, Expanded(child: stage)]);
              },
            ),
          ),
        );
      },
    ),
  );
}
