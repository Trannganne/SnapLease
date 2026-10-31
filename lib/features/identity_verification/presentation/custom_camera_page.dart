import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../rental/bloc/rental_bloc.dart';

import '../../../core/widgets/reservation_timer.dart';
import '../services/identity_scanner.dart';

class CustomCameraPage extends StatefulWidget {
  final bool isFront;
  final bool fromAccount;

  const CustomCameraPage({
    super.key,
    required this.isFront,
    this.fromAccount = false,
  });

  @override
  State<CustomCameraPage> createState() => _CustomCameraPageState();
}

class _CustomCameraPageState extends State<CustomCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isReady = false;
  bool _isProcessing = false;
  String? _errorMsg;
  bool _initializing = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (_initializing || !mounted) return;
    _initializing = true;
    final generation = ++_generation;
    setState(() {
      _errorMsg = null;
      _isReady = false;
    });
    try {
      final previous = _controller;
      _controller = null;
      await previous?.dispose();
      _cameras = await availableCameras();
      if (!mounted || generation != _generation) return;
      if (_cameras.isEmpty) {
        setState(() => _errorMsg = 'Không tìm thấy camera');
        return;
      }
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      _controller = CameraController(
        backCamera,
        ResolutionPreset.max,
        enableAudio: false,
      );
      final controller = _controller!;
      await controller.initialize();
      if (!mounted || generation != _generation) return;
      try {
        await controller.setFocusMode(FocusMode.auto);
      } on CameraException {
        /* Camera may not support focus control. */
      }
      if (mounted && generation == _generation) setState(() => _isReady = true);
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _errorMsg =
                  e is CameraException &&
                          (e.code.contains('AccessDenied') ||
                              e.code.contains('AccessRestricted'))
                      ? 'Chưa có quyền camera. Hãy cấp quyền Camera trong Cài đặt ứng dụng rồi thử lại.'
                      : 'Không thể mở camera. Vui lòng đóng ứng dụng đang dùng camera và thử lại.',
        );
      }
    } finally {
      _initializing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_initializing || !_isReady) return;
      _generation++;
      _isReady = false;
      final controller = _controller;
      _controller = null;
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed && !_isProcessing) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture(BoxConstraints constraints) async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) {
      return;
    }
    setState(() => _isProcessing = true);
    final controller = _controller!;
    String? rawPath;
    String? outputPath;
    bool handedOff = false;
    try {
      final xFile = await controller.takePicture();
      rawPath = xFile.path;
      if (!mounted || controller != _controller) return;

      // Calculate layout coordinates
      final previewRatio = 1 / controller.value.aspectRatio; // Portrait

      double previewWidth = constraints.maxWidth;
      double previewHeight = previewWidth / previewRatio;

      if (previewHeight > constraints.maxHeight) {
        previewHeight = constraints.maxHeight;
        previewWidth = previewHeight * previewRatio;
      }

      final frameWidth = previewWidth * 0.9;
      final frameHeight = frameWidth / 1.586; // ID-1 ratio
      final dx = (previewWidth - frameWidth) / 2;
      final dy = (previewHeight - frameHeight) / 2;

      final bytes = await xFile.readAsBytes();
      img.Image? captured = img.decodeImage(bytes);
      if (captured == null) throw Exception('Cannot decode image');

      // Fix orientation if needed
      captured = img.bakeOrientation(captured);

      final scaleX = captured.width / previewWidth;
      final scaleY = captured.height / previewHeight;

      // Map to image coordinates using BoxFit.cover logic
      final scale = scaleX < scaleY ? scaleX : scaleY;

      final mappedPreviewW = previewWidth * scale;
      final mappedPreviewH = previewHeight * scale;

      final offsetX = (captured.width - mappedPreviewW) / 2;
      final offsetY = (captured.height - mappedPreviewH) / 2;

      // Expand crop area slightly (10%) to ensure we don't cut off text at edges
      final cropDx = (dx - frameWidth * 0.1).clamp(0.0, previewWidth);
      final cropDy = (dy - frameHeight * 0.1).clamp(0.0, previewHeight);
      final cropFrameW = (frameWidth * 1.2).clamp(0.0, previewWidth - cropDx);
      final cropFrameH = (frameHeight * 1.2).clamp(0.0, previewHeight - cropDy);

      // Map to image coordinates
      final cropX = (cropDx * scale + offsetX).toInt().clamp(0, captured.width);
      final cropY = (cropDy * scale + offsetY).toInt().clamp(
        0,
        captured.height,
      );
      final cropW = (cropFrameW * scale).toInt().clamp(
        0,
        captured.width - cropX,
      );
      final cropH = (cropFrameH * scale).toInt().clamp(
        0,
        captured.height - cropY,
      );

      final cropped = img.copyCrop(
        captured,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      final tempDir = await getTemporaryDirectory();

      // Save debug info if enabled
      if (widget.isFront) {
        if (ScanDebugData.enableDebug) {
          ScanDebugData.clearFront();
          final debugPath =
              '${tempDir.path}/raw_capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await File(
            debugPath,
          ).writeAsBytes(img.encodeJpg(captured, quality: 50));
          ScanDebugData.rawCapturedImagePath = debugPath;
          ScanDebugData.cropRect = Rect.fromLTWH(
            cropX.toDouble(),
            cropY.toDouble(),
            cropW.toDouble(),
            cropH.toDouble(),
          );
        }
      }

      final targetPath =
          '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(targetPath);
      outputPath = targetPath;
      await file.writeAsBytes(img.encodeJpg(cropped, quality: 90));

      if (mounted) {
        handedOff = true;
        context.pop(file.path);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể xử lý ảnh. Vui lòng giữ máy ổn định và chụp lại.',
            ),
          ),
        );
      }
    } finally {
      for (final path in [rawPath, if (!handedOff) outputPath]) {
        if (path != null) {
          try {
            await File(path).delete();
          } catch (_) {}
        }
      }
      if (mounted && !handedOff) {
        setState(() => _isProcessing = false);
        if (_controller == null &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          _initCamera();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child:
            _errorMsg != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMsg!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: _initCamera,
                          child: const Text('Thử lại camera'),
                        ),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Quay lại'),
                        ),
                      ],
                    ),
                  ),
                )
                : (!_isReady || _controller == null)
                ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
                : Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final previewRatio = 1 / _controller!.value.aspectRatio;
                        return Center(
                          child: AspectRatio(
                            aspectRatio: previewRatio,
                            child: Stack(
                              children: [
                                CameraPreview(_controller!),
                                CustomPaint(
                                  size: Size.infinite,
                                  painter: _OverlayPainter(),
                                ),
                                Positioned(
                                  top: 40,
                                  left: 0,
                                  right: 0,
                                  child: Text(
                                    widget.isFront
                                        ? 'Đặt mặt trước căn cước vào khung'
                                        : 'Đặt mặt sau căn cước vào khung',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  bottom: 120,
                                  left: 0,
                                  right: 0,
                                  child: Text(
                                    'Không để chói sáng, không che chữ và QR',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 24,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: GestureDetector(
                                      onTap:
                                          _isProcessing
                                              ? null
                                              : () => _takePicture(constraints),
                                      child: Container(
                                        height: 72,
                                        width: 72,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 4,
                                          ),
                                          color:
                                              _isProcessing
                                                  ? Colors.grey
                                                  : Colors.transparent,
                                        ),
                                        child: Center(
                                          child: Container(
                                            height: 56,
                                            width: 56,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                            ),
                                            child:
                                                _isProcessing
                                                    ? const CircularProgressIndicator()
                                                    : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    if (!widget.fromAccount)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: BlocBuilder<RentalBloc, RentalState>(
                          builder: (context, state) {
                            if (state.maGiuCho != null &&
                                !state.isReservationExpired &&
                                state.initialTimeRemaining != null) {
                              return ReservationTimer(
                                initialTimeRemaining:
                                    state.initialTimeRemaining!,
                                stopwatch:
                                    context
                                        .read<RentalBloc>()
                                        .reservationStopwatch,
                                onExpired: () {
                                  context.read<RentalBloc>().add(
                                    const FetchActiveReservation(),
                                  );
                                },
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = size.width * 0.9;
    final frameHeight = frameWidth / 1.586;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameWidth,
      height: frameHeight,
    );

    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);

    final path =
        Path()
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)))
          ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    final borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
