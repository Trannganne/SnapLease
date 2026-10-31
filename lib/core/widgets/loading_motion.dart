import 'package:flutter/material.dart';

/// One clock per loading region. Never advances while hidden or backgrounded.
class LoadingMotion extends StatefulWidget {
  final Duration duration;
  final Widget Function(BuildContext, Animation<double>, bool) builder;
  const LoadingMotion({
    super.key,
    required this.builder,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<LoadingMotion> createState() => _LoadingMotionState();
}

class _LoadingMotionState extends State<LoadingMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  void _sync() {
    final animate =
        _foreground &&
        TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !_clock.isAnimating) _clock.repeat();
    if (!animate) _clock.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _clock, MediaQuery.disableAnimationsOf(context));
}
