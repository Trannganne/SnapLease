import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/app_availability_calendar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/snap_loading_view.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../branches/presentation/branch_choice_tile.dart';
import '../domain/chat_repository.dart';
import 'chat_availability_cubit.dart';

class ChatAvailabilitySheet extends StatelessWidget {
  final String productId;
  final ChatRepository repository;
  const ChatAvailabilitySheet({
    super.key,
    required this.productId,
    required this.repository,
  });
  @override
  Widget build(BuildContext context) => BlocProvider(
    create:
        (_) => ChatAvailabilityCubit(
          branches: CatalogRepository(),
          repository: repository,
          productId: productId,
        )..load(),
    child: BlocBuilder<ChatAvailabilityCubit, ChatAvailabilityState>(
      builder: (context, state) {
        final cubit = context.read<ChatAvailabilityCubit>();
        final format = DateFormat('HH:mm dd/MM/yyyy');
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: Column(
            children: [
              ListTile(
                title: const AppText(
                  'Kiểm tra lịch trống',
                  fontWeight: FontWeight.bold,
                ),
                trailing: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.pageMargin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppText(
                        'Chọn chi nhánh, giờ nhận và giờ trả. Kết quả chỉ là thông tin tại lúc kiểm tra, chưa giữ chỗ.',
                        fontSize: 12,
                      ),
                      const SizedBox(height: AppSizes.spacingM),
                      if (state.loading)
                        const Center(child: SnapButtonLoader()),
                      for (final branch in state.branches)
                        BranchChoiceTile(
                          name: branch.name,
                          address: branch.address ?? '',
                          selected: branch.id == state.selectedId,
                          onTap: () => cubit.select(branch.id),
                        ),
                      if (state.error != null) AppText(state.error!),
                      if (state.start != null && state.end != null)
                        AppText(
                          '${format.format(state.start!)} → ${format.format(state.end!)}',
                        ),
                      if (state.count != null) ...[
                        AppText(
                          state.count! > 0
                              ? 'Còn ${state.count} thiết bị tại lúc kiểm tra.'
                              : 'Không còn máy trong khoảng thời gian đã chọn.',
                          fontWeight: FontWeight.w600,
                        ),
                        AppText(
                          'Kiểm tra lúc ${format.format(state.checkedAt!)}. Luồng thuê sẽ kiểm tra lại.',
                          fontSize: 12,
                        ),
                      ],
                      const SizedBox(height: AppSizes.spacingM),
                      PrimaryButton(
                        text:
                            state.checking
                                ? 'Đang kiểm tra'
                                : 'Chọn thời gian và kiểm tra',
                        isLoading: state.checking,
                        onPressed:
                            state.selectedId == null || state.checking
                                ? null
                                : () async {
                                  final id = state.selectedId;
                                  final dates =
                                      await AppAvailabilityCalendar.show(
                                        context,
                                        branchId: id,
                                        deviceId: productId,
                                        quantity: 1,
                                        currentPickup: state.start,
                                        currentReturn: state.end,
                                      );
                                  if (context.mounted &&
                                      !cubit.isClosed &&
                                      id == cubit.state.selectedId &&
                                      dates != null) {
                                    await cubit.check(
                                      dates['pickup']!,
                                      dates['return']!,
                                    );
                                  }
                                },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
