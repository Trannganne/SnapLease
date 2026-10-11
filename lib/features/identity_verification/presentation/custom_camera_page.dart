import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../rental/bloc/rental_bloc.dart';

import '../../../../core/widgets/reservation_timer.dart';
import '../services/identity_scanner.dart';

class CustomCameraPage extends StatefulWidget {
  final bool isFront;

  const CustomCameraPage({super.key, required this.isFront});

  @override
  State<CustomCameraPage> createState() => _CustomCameraPageState();
}

class _CustomCameraPageState extends State<CustomCameraPage> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isReady = false;
  bool _isProcessing = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMsg = 'Không tìm thấy camera');
        return;
      }
      final backCamera = _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first);
      _controller = CameraController(
        backCamera,
        ResolutionPreset.max,
        enableAudio: false,
      );
      await _controller!.initialize();
      await _controller!.setFocusMode(FocusMode.auto);
      if (mounted) setState(() => _isReady = true);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Lỗi camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture(BoxConstraints constraints) async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final xFile = await _controller!.takePicture();
      
      // Calculate layout coordinates
      final previewRatio = 1 / _controller!.value.aspectRatio; // Portrait
      
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
      final cropY = (cropDy * scale + offsetY).toInt().clamp(0, captured.height);
      final cropW = (cropFrameW * scale).toInt().clamp(0, captured.width - cropX);
      final cropH = (cropFrameH * scale).toInt().clamp(0, captured.height - cropY);

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
             final debugPath = '${tempDir.path}/raw_capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
             await File(debugPath).writeAsBytes(img.encodeJpg(captured, quality: 50));
             ScanDebugData.rawCapturedImagePath = debugPath;
             ScanDebugData.cropRect = Rect.fromLTWH(cropX.toDouble(), cropY.toDouble(), cropW.toDouble(), cropH.toDouble());
         }
      }

      final targetPath = '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(targetPath);
      await file.writeAsBytes(img.encodeJpg(cropped, quality: 90));

      if (mounted) {
        context.pop(file.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi chụp: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _errorMsg != null
            ? Center(child: Text(_errorMsg!, style: const TextStyle(color: Colors.white)))
            : (!_isReady || _controller == null)
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
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
                                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 24,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: _isProcessing ? null : () => _takePicture(constraints),
                                        child: Container(
                                          height: 72,
                                          width: 72,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 4),
                                            color: _isProcessing ? Colors.grey : Colors.transparent,
                                          ),
                                          child: Center(
                                            child: Container(
                                              height: 56,
                                              width: 56,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                              ),
                                              child: _isProcessing
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
                          icon: const Icon(Icons.close, color: Colors.white, size: 30),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: BlocBuilder<RentalBloc, RentalState>(
                          builder: (context, state) {
                            if (state.maGiuCho != null &&
                                !state.isReservationExpired &&
                                state.initialTimeRemaining != null) {
                              return ReservationTimer(
                                initialTimeRemaining: state.initialTimeRemaining!,
                                stopwatch: context.read<RentalBloc>().reservationStopwatch,
                                onExpired: () {
                                  context.read<RentalBloc>().add(const FetchActiveReservation());
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
    
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
