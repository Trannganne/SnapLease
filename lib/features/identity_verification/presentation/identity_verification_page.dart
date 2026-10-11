import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../bloc/identity_verification_bloc.dart';
import '../bloc/identity_verification_event.dart';
import '../bloc/identity_verification_state.dart';
import '../services/identity_scanner.dart';
import 'widgets/cccd_image_picker_card.dart';
import 'widgets/capture_requirements_card.dart';
import 'widgets/security_card.dart';
import 'widgets/verification_progress.dart';
import 'widgets/verification_result_review.dart';
import '../../../../core/widgets/reservation_timer.dart';
import '../../rental/bloc/rental_bloc.dart';
import 'custom_camera_page.dart';
import 'qr_scanner_page.dart';
class IdentityVerificationPage extends StatelessWidget {
  const IdentityVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => IdentityVerificationBloc(),
      child: const IdentityVerificationView(),
    );
  }
}

class IdentityVerificationView extends StatelessWidget {
  const IdentityVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldCancel = await showCancelReservationDialog(context);
        if (shouldCancel && context.mounted) {
          context.read<RentalBloc>().add(const CancelReservation());
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/device/${context.read<RentalBloc>().state.selectedDevice?.id}');
          }
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () async {
              final shouldCancel = await showCancelReservationDialog(context);
              if (shouldCancel && context.mounted) {
                context.read<RentalBloc>().add(const CancelReservation());
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/device/${context.read<RentalBloc>().state.selectedDevice?.id}');
                }
              }
            },
          ),
          title: AppText(
            'Xác minh danh tính',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Builder(
                  builder: (context) {
                    final initialTimeRemaining = context.select((RentalBloc bloc) => bloc.state.initialTimeRemaining);
                    final isSyncing = context.select((RentalBloc bloc) => bloc.state.isSyncingReservation);
                    final stopwatch = context.read<RentalBloc>().reservationStopwatch;

                    if (initialTimeRemaining != null) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (kDebugMode || true) // Vẫn hiện để test 
                            IconButton(
                              icon: const Icon(Icons.bug_report, color: Colors.orange),
                              onPressed: () => _showDebugDialog(context),
                            ),
                          ReservationTimer(
                            initialTimeRemaining: initialTimeRemaining,
                            stopwatch: stopwatch,
                            isSyncing: isSyncing,
                            onExpired: () {
                              context.read<RentalBloc>().add(const CheckReservationStatus());
                            },
                            onResume: () {
                              context.read<RentalBloc>().add(const FetchActiveReservation());
                            },
                          ),
                        ],
                      );
                    }
                    if (kDebugMode || true) {
                       return IconButton(
                          icon: const Icon(Icons.bug_report, color: Colors.orange),
                          onPressed: () => _showDebugDialog(context),
                       );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        ),
        body: MultiBlocListener(
          listeners: [
            BlocListener<IdentityVerificationBloc, IdentityVerificationState>(
              listener: (context, state) {
                if ((state.status == IdentityVerificationStatus.error || state.status == IdentityVerificationStatus.confirmError) &&
                    state.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.errorMessage!),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                } else if (state.status ==
                    IdentityVerificationStatus.verificationSuccess) {
                  final rentalState = context.read<RentalBloc>().state;
                  if (!rentalState.isReservationExpired) {
                    context.read<RentalBloc>().add(const LoadCustomerProfile());
                    context.pushReplacement('/rental-confirmation');
                  }
                } else if (state.status ==
                    IdentityVerificationStatus.verificationFailed) {
                  // context.push(
                  //   '/identity-verification/error',
                  //   extra: context.read<IdentityVerificationBloc>(),
                  // );
                }
              },
            ),
            BlocListener<RentalBloc, RentalState>(
              listenWhen: (previous, current) => previous.isReservationExpired != current.isReservationExpired,
              listener: (context, state) {
                if (state.isReservationExpired) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thời gian giữ chỗ đã hết hạn. Vui lòng thực hiện lại.')),
                  );
                  if (context.canPop()) {
                    context.pop();
                  } else if (state.selectedDevice != null) {
                    context.go('/device/${state.selectedDevice!.id}');
                  } else {
                    context.go('/');
                  }
                }
              },
            ),
          ],
          child: BlocBuilder<IdentityVerificationBloc, IdentityVerificationState>(
            builder: (context, state) {
          final isCompleted =
              state.frontImage != null && state.backImage != null;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VerificationProgress(
                        currentStep: (state.status == IdentityVerificationStatus.success || state.status == IdentityVerificationStatus.confirming || state.status == IdentityVerificationStatus.confirmError) ? 2 : (isCompleted ? 2 : 1),
                        totalSteps: 3,
                      ),
                      if ((state.status == IdentityVerificationStatus.success || state.status == IdentityVerificationStatus.confirming || state.status == IdentityVerificationStatus.confirmError) && state.extractedData != null)
                        VerificationResultReview(data: state.extractedData!)
                      else ...[
                        SizedBox(height: 24),
                        const AppText(
                          'Xác minh CCCD',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        const SizedBox(height: 8),
                        AppText(
                          'Vui lòng cung cấp ảnh rõ nét của hai mặt Căn cước công dân để tiếp tục quá trình thuê thiết bị.',
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                        const SizedBox(height: 24),
                        SecurityCard(isCompleted: isCompleted),
                        const SizedBox(height: 24),
                      CccdImagePickerCard(
                        sideTitle: 'Mặt trước CCCD',
                        cardTitle: 'Tải ảnh mặt trước CCCD',
                        cardSubtitle: 'Hỗ trợ JPG, PNG (Tối đa 10MB)',
                        selectedImage: state.frontImage,
                        onCameraTap: () async {
                          final path = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomCameraPage(isFront: true),
                            ),
                          );
                          if (path != null && context.mounted) {
                            context.read<IdentityVerificationBloc>().add(SetFrontImage(path));
                          }
                        },
                        onGalleryTap:
                            () => context.read<IdentityVerificationBloc>().add(
                              const PickFrontImage(ImageSource.gallery),
                            ),
                        onRetake: () async {
                          final path = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomCameraPage(isFront: true),
                            ),
                          );
                          if (path != null && context.mounted) {
                            context.read<IdentityVerificationBloc>().add(SetFrontImage(path));
                          }
                        },
                        onDelete:
                            () => context.read<IdentityVerificationBloc>().add(
                              RemoveFrontImage(),
                            ),
                      ),
                      if (state.status == IdentityVerificationStatus.error && 
                          state.errorMessage != null && 
                          state.errorMessage!.contains('QR') && 
                          state.frontImage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: InkWell(
                            onTap: () async {
                              final qrData = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const QrScannerPage(),
                                ),
                              );
                              if (qrData != null && context.mounted) {
                                context.read<IdentityVerificationBloc>().add(SetManuallyScannedQr(qrData));
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                                border: Border.all(color: Theme.of(context).colorScheme.error),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.qr_code_scanner, color: Theme.of(context).colorScheme.error),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        AppText(
                                          'Quét mã QR trực tiếp',
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                        AppText(
                                          'Dùng camera quét mã QR nếu ảnh chụp không rõ',
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.error),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      CccdImagePickerCard(
                        sideTitle: 'Mặt sau CCCD',
                        cardTitle: 'Tải ảnh mặt sau CCCD',
                        cardSubtitle: 'Bao gồm dải mã vạch chip điện tử',
                        selectedImage: state.backImage,
                        onCameraTap: () async {
                          final path = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomCameraPage(isFront: false),
                            ),
                          );
                          if (path != null && context.mounted) {
                            context.read<IdentityVerificationBloc>().add(SetBackImage(path));
                          }
                        },
                        onGalleryTap:
                            () => context.read<IdentityVerificationBloc>().add(
                              const PickBackImage(ImageSource.gallery),
                            ),
                        onRetake: () async {
                          final path = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomCameraPage(isFront: false),
                            ),
                          );
                          if (path != null && context.mounted) {
                            context.read<IdentityVerificationBloc>().add(SetBackImage(path));
                          }
                        },
                        onDelete:
                            () => context.read<IdentityVerificationBloc>().add(
                              RemoveBackImage(),
                            ),
                      ),
                      const SizedBox(height: 24),
                      const CaptureRequirementsCard(),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: state.isConsentAccepted,
                              onChanged: (value) {
                                if (value != null) {
                                  context.read<IdentityVerificationBloc>().add(
                                    ToggleConsent(value),
                                  );
                                }
                              },
                              activeColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: AppText(
                              'Tôi xác nhận các hình ảnh trên là chính chủ và đồng ý cho SNAPLEASE sử dụng để xác minh danh tính và tạo hợp đồng thuê thiết bị.',
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      ],
                    ],
                  ),
                ),
              ),
              if (state.status != IdentityVerificationStatus.success)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        offset: const Offset(0, -4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      text: 'Tiếp tục xác minh →',
                      onPressed:
                          state.isReadyToSubmit && isCompleted
                              ? () => context
                                  .read<IdentityVerificationBloc>()
                                  .add(SubmitVerification())
                              : null,
                      isLoading:
                          state.status == IdentityVerificationStatus.loading,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    )));
  }

  void _showDebugDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Chẩn đoán OCR Cơ quan cấp'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Bật mode chẩn đoán (thu thập toạ độ khi chụp ảnh)', style: TextStyle(fontSize: 14)),
                    value: ScanDebugData.enableDebug,
                    onChanged: (val) {
                      setState(() {
                        ScanDebugData.enableDebug = val;
                      });
                    },
                  ),
                  if (ScanDebugData.enableDebug) ...[
                    const Divider(),
                    const Text('Kết quả Scanner:', style: TextStyle(fontWeight: FontWeight.bold)),
                    if (!ScanDebugData.isScanned)
                      const Text('Trạng thái: CHƯA QUÉT (Đang chờ nộp ảnh)', style: TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.bold))
                    else ...[
                      if (ScanDebugData.barcodeDiagnostic != null)
                        Text(ScanDebugData.barcodeDiagnostic!, style: const TextStyle(fontSize: 13, color: Colors.blue)),
                      if (ScanDebugData.qrException != null)
                        Text('Exception: ${ScanDebugData.qrException}', style: const TextStyle(fontSize: 13, color: Colors.red)),
                      Text('Số barcode tìm thấy: ${ScanDebugData.barcodeCount}', style: const TextStyle(fontSize: 13)),
                      if (ScanDebugData.barcodeTypes.isNotEmpty)
                        Text('Loại: ${ScanDebugData.barcodeTypes.join(", ")}', style: const TextStyle(fontSize: 13)),
                    ],
                    
                    if (ScanDebugData.rawCapturedImagePath != null) ...[
                       const SizedBox(height: 8),
                       const Text('Ảnh RAW (chưa crop):', style: TextStyle(fontWeight: FontWeight.bold)),
                       AspectRatio(
                         aspectRatio: 3/4,
                         child: Stack(
                           children: [
                             Image.file(File(ScanDebugData.rawCapturedImagePath!), fit: BoxFit.contain),
                             if (ScanDebugData.cropRect != null)
                               Positioned.fill(
                                 child: CustomPaint(
                                   painter: _CropRectPainter(ScanDebugData.cropRect!),
                                 ),
                               ),
                           ]
                         ),
                       ),
                    ],
                    
                    if (ScanDebugData.frontImagePath != null) ...[
                       const SizedBox(height: 16),
                       const Text('Ảnh toàn thẻ sau crop (File quét gốc):', style: TextStyle(fontWeight: FontWeight.bold)),
                       if (ScanDebugData.frontImageSize != null)
                         Text('Kích thước ảnh: ${ScanDebugData.frontImageSize!.width}x${ScanDebugData.frontImageSize!.height} px', style: const TextStyle(fontSize: 12)),
                       const SizedBox(height: 4),
                       AspectRatio(
                         aspectRatio: (ScanDebugData.frontImageSize?.width ?? 3) / (ScanDebugData.frontImageSize?.height ?? 4),
                         child: Stack(
                           children: [
                             Image.file(File(ScanDebugData.frontImagePath!), fit: BoxFit.contain),
                             if (ScanDebugData.fallbackCropRect != null && ScanDebugData.frontImageSize != null)
                               Positioned.fill(
                                 child: CustomPaint(
                                   painter: _OcrRectPainter([ScanDebugData.fallbackCropRect!], ScanDebugData.frontImageSize!),
                                 ),
                               ),
                           ]
                         ),
                       ),
                       if (ScanDebugData.fallbackCropRect != null)
                          Text('Vùng vẽ tay: x=${ScanDebugData.fallbackCropRect!.left}, y=${ScanDebugData.fallbackCropRect!.top}, w=${ScanDebugData.fallbackCropRect!.width}, h=${ScanDebugData.fallbackCropRect!.height}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                    ],
                    
                    if (ScanDebugData.fallbackImagePath != null) ...[
                       const SizedBox(height: 16),
                       const Text('Ảnh crop QR dự phòng (File quét fallback):', style: TextStyle(fontWeight: FontWeight.bold)),
                       if (ScanDebugData.fallbackCropRect != null)
                         Text('Kích thước crop: ${ScanDebugData.fallbackCropRect!.width}x${ScanDebugData.fallbackCropRect!.height} px', style: const TextStyle(fontSize: 12)),
                       const SizedBox(height: 4),
                       SizedBox(
                         height: 200,
                         width: MediaQuery.of(context).size.width,
                         child: InteractiveViewer(
                           panEnabled: true,
                           minScale: 1.0,
                           maxScale: 4.0,
                           child: Image.file(File(ScanDebugData.fallbackImagePath!), fit: BoxFit.contain),
                         ),
                       ),
                    ],
                  ],
                  if (ScanDebugData.backImagePath != null && ScanDebugData.imageSize != null) ...[
                    const Divider(),
                    const Text('Các dòng ứng viên (Nơi Cấp):', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...ScanDebugData.issuerTexts.map((e) => Text(e, style: const TextStyle(fontSize: 12))),
                    const SizedBox(height: 12),
                    AspectRatio(
                      aspectRatio: ScanDebugData.imageSize!.width / ScanDebugData.imageSize!.height,
                      child: Stack(
                        children: [
                          Image.file(
                            File(ScanDebugData.backImagePath!),
                            fit: BoxFit.fill,
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _OcrRectPainter(ScanDebugData.issuerRects, ScanDebugData.imageSize!),
                            ),
                          ),
                        ],
                      ),
                    )
                  ] else if (ScanDebugData.enableDebug) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('Vui lòng chụp ảnh để xem dữ liệu chẩn đoán.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    )
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OcrRectPainter extends CustomPainter {
  final List<Rect> rects;
  final Size imageSize;
  
  _OcrRectPainter(this.rects, this.imageSize);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;
    
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
      
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    
    for (final rect in rects) {
      canvas.drawRect(
        Rect.fromLTRB(
          rect.left * scaleX,
          rect.top * scaleY,
          rect.right * scaleX,
          rect.bottom * scaleY,
        ),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CropRectPainter extends CustomPainter {
  final Rect cropRect;
  _CropRectPainter(this.cropRect);
  
  @override
  void paint(Canvas canvas, Size size) {
     // Debug drawing for cropRect omitted to avoid math crash without full image size.
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

