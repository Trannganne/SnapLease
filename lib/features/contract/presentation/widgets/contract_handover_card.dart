import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_text.dart';
import '../../data/repositories/contract_repository.dart';
import '../../domain/models/handover_models.dart';
import '../../services/contract_pdf_service.dart';
import '../bloc/handover_image_cubit.dart';

class ContractHandoverCard extends StatelessWidget {
  final ContractModel contract;
  final ContractRepository? repository;
  final bool showSchedule;
  const ContractHandoverCard({
    super.key,
    required this.contract,
    this.repository,
    this.showSchedule = true,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<BookedContractDevice>>{};
    for (final booked in contract.bookedDevices) {
      groups.putIfAbsent(booked.modelId, () => []).add(booked);
    }
    for (final device in contract.assignedDevices) {
      groups.putIfAbsent(device.modelId, () => []);
    }
    final deliveredStatus = [
      'DANG_THUE',
      'CHO_HOAN_TRA',
      'HOAN_THANH',
    ].contains(contract.status);
    final format = DateFormat('HH:mm • dd/MM/yyyy');
    String missing(String kind, AssignedContractDevice device) =>
        deliveredStatus || device.handedOverAt != null
            ? 'Chưa có thông tin $kind'
            : 'Chưa bàn giao';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'Thiết bị thuê và bàn giao',
            fontWeight: FontWeight.bold,
          ),
          if (groups.isEmpty)
            const AppText('Chưa có thông tin dòng máy đặt thuê.'),
          for (final group in groups.entries) ...[
            const Divider(height: 24),
            AppText(
              group.value.isEmpty ? group.key : group.value.first.name,
              fontWeight: FontWeight.w600,
            ),
            AppText(
              group.value.isEmpty
                  ? 'Chưa có thông tin số lượng thuê'
                  : 'Số lượng thuê: ${group.value.fold<int>(0, (sum, row) => sum + row.quantity)} • Đã gán ${contract.assignedDevices.where((d) => d.modelId == group.key).length}/${group.value.fold<int>(0, (sum, row) => sum + row.quantity)} thiết bị',
            ),
            for (final booked in group.value)
              if (booked.start != null && booked.end != null)
                AppText(
                  'Thuê: ${format.format(booked.start!)} → ${format.format(booked.end!)}',
                  fontSize: 12,
                ),
            if (!contract.assignedDevices.any((d) => d.modelId == group.key))
              const AppText('Chưa gán thiết bị', fontSize: 13),
            for (final device in contract.assignedDevices.where(
              (d) => d.modelId == group.key,
            )) ...[
              const SizedBox(height: 12),
              AppText(
                'Serial: ${device.serial?.trim().isNotEmpty == true ? device.serial : 'Chưa có thông tin serial'}',
                fontWeight: FontWeight.w600,
              ),
              AppText(
                'Tình trạng giao: ${device.handoverCondition?.trim().isNotEmpty == true ? device.handoverCondition : missing('tình trạng giao', device)}',
                fontSize: 13,
              ),
              AppText(
                'Giao thực tế: ${device.handedOverAt == null ? missing('ngày giao thực tế', device) : format.format(device.handedOverAt!)}',
                fontSize: 13,
              ),
              if (device.images.any(
                (image) => image.type == 'BAN_GIAO' && image.url.isNotEmpty,
              )) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final image in device.images.where(
                      (image) =>
                          image.type == 'BAN_GIAO' && image.url.isNotEmpty,
                    ))
                      HandoverThumbnail(
                        key: ValueKey('${device.detailId}:${image.url}'),
                        image: image,
                        repository: repository,
                      ),
                  ],
                ),
              ],
            ],
          ],
          if (showSchedule) ...[
            const Divider(height: 24),
            AppText(
              'Nhận dự kiến: ${format.format(contract.pickupDate)}',
              fontSize: 13,
            ),
            AppText(
              'Hạn trả: ${format.format(contract.returnDate)}',
              fontSize: 13,
            ),
            AppText('Chi nhánh: ${contract.branchName}', fontSize: 13),
            if (contract.lessorAddress.isNotEmpty)
              AppText(contract.lessorAddress, fontSize: 13),
          ],
        ],
      ),
    );
  }
}

class HandoverThumbnail extends StatelessWidget {
  final HandoverImage image;
  final ContractRepository? repository;
  const HandoverThumbnail({super.key, required this.image, this.repository});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create:
        (_) =>
            HandoverImageCubit()
              ..load(image.url, repository ?? ContractRepository()),
    child: BlocBuilder<HandoverImageCubit, HandoverImageState>(
      builder:
          (context, state) => Semantics(
            label: image.description ?? 'Ảnh bàn giao',
            image: true,
            child: InkWell(
              onTap:
                  state.bytes == null
                      ? null
                      : () => showDialog<void>(
                        context: context,
                        builder:
                            (dialogContext) => Dialog(
                              child: SizedBox(
                                height:
                                    MediaQuery.sizeOf(dialogContext).height *
                                    0.7,
                                child: Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.topRight,
                                      child: IconButton(
                                        tooltip: 'Đóng ảnh',
                                        icon: const Icon(Icons.close),
                                        onPressed:
                                            () =>
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop(),
                                      ),
                                    ),
                                    Expanded(
                                      child: InteractiveViewer(
                                        minScale: 1,
                                        maxScale: 4,
                                        child: Center(
                                          child: Image.memory(
                                            state.bytes!,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (_, _, _) => const Text(
                                                  'Không tải được ảnh',
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ),
              child: SizedBox(
                width: 80,
                height: 80,
                child:
                    state.failed
                        ? const Center(
                          child: Text(
                            'Không tải được ảnh',
                            textAlign: TextAlign.center,
                          ),
                        )
                        : state.bytes == null
                        ? const Center(child: CircularProgressIndicator())
                        : Image.memory(
                          state.bytes!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, _, _) => const Center(
                                child: Text('Không tải được ảnh'),
                              ),
                        ),
              ),
            ),
          ),
    ),
  );
}
