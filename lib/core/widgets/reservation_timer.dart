import 'dart:async';
import 'package:flutter/material.dart';
import 'app_text.dart';

class ReservationTimer extends StatefulWidget {
  final Duration initialTimeRemaining;
  final Stopwatch stopwatch;
  final bool isSyncing;
  final VoidCallback onExpired;
  final VoidCallback? onResume;

  const ReservationTimer({
    super.key,
    required this.initialTimeRemaining,
    required this.stopwatch,
    this.isSyncing = false,
    required this.onExpired,
    this.onResume,
  });

  @override
  State<ReservationTimer> createState() => _ReservationTimerState();
}

class _ReservationTimerState extends State<ReservationTimer> with WidgetsBindingObserver {
  late Timer _timer;
  Duration _remaining = Duration.zero;
  bool _hasFiredExpired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  @override
  void didUpdateWidget(ReservationTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTimeRemaining != oldWidget.initialTimeRemaining || widget.isSyncing != oldWidget.isSyncing) {
      if (widget.initialTimeRemaining > Duration.zero && !widget.isSyncing) {
        _hasFiredExpired = false;
      }
      _updateRemaining();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.onResume?.call();
    }
  }

  void _updateRemaining() {
    if (widget.isSyncing) return;
    
    setState(() {
      _remaining = widget.initialTimeRemaining - widget.stopwatch.elapsed;
    });
    
    if (_remaining.isNegative && !_hasFiredExpired) {
      _hasFiredExpired = true;
      widget.onExpired();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSyncing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 6),
            AppText(
              'Đang đồng bộ',
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ],
        ),
      );
    }

    if (_remaining.isNegative) {
      return const SizedBox.shrink();
    }
    
    final minutes = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 4),
          AppText(
            '$minutes:$seconds',
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }
}

Future<bool> showCancelReservationDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hủy giữ chỗ?'),
      content: const Text(
          'Nếu quay lại, giữ chỗ hiện tại sẽ bị hủy và thiết bị có thể được người khác thuê.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Tiếp tục thuê'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Hủy giữ chỗ', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return result ?? false;
}
