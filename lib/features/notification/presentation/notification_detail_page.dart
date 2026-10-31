import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/primary_button.dart';
import '../bloc/notification_detail_cubit.dart';
import '../bloc/notification_detail_state.dart';
import '../data/repositories/notification_repository.dart';
import '../domain/models/notification_item_model.dart';
import '../../contract/data/repositories/contract_repository.dart';
import '../../contract/services/contract_pdf_service.dart';
import 'models/notification_detail_view_data.dart';
import 'widgets/notification_detail_summary_card.dart';
import 'widgets/notification_detail_content_card.dart';
import 'widgets/notification_return_warning_card.dart';
import 'widgets/notification_related_contract_card.dart';
import 'widgets/notification_demo_banner.dart';
import 'package:rentcam/features/contract/domain/models/extension_models.dart';
import 'package:rentcam/features/contract/presentation/widgets/contract_extension_card.dart';
import 'package:rentcam/core/navigation/app_route_observer.dart';

class NotificationDetailPage extends StatelessWidget {
  final String notificationId;
  final NotificationItemModel? initialItem;
  final NotificationRepository? notificationRepository;
  final ContractRepository? contractRepository;
  final bool isDemo;
  final ContractModel? demoContract;
  final String? demoVariant;
  final Map<String, dynamic>? demoMetadata;

  const NotificationDetailPage({
    super.key,
    required this.notificationId,
    this.initialItem,
    this.notificationRepository,
    this.contractRepository,
    this.isDemo = false,
    this.demoContract,
    this.demoVariant,
    this.demoMetadata,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => NotificationDetailCubit(
            notificationId: notificationId,
            initialItem: initialItem,
            notificationRepository:
                notificationRepository ?? DioNotificationRepository(),
            contractRepository: contractRepository ?? ContractRepository(),
            isDemo: isDemo,
            demoContract: demoContract,
            demoVariant: demoVariant,
            demoMetadata: demoMetadata,
          ),
      child: const NotificationDetailView(),
    );
  }
}

class NotificationDetailView extends StatefulWidget {
  const NotificationDetailView({super.key});

  @override
  State<NotificationDetailView> createState() => _NotificationDetailViewState();
}

class _NotificationDetailViewState extends State<NotificationDetailView>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<dynamic>? _route;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      appRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) appRouteObserver.subscribe(this, route);
    }
  }

  void _refresh() {
    if (mounted) context.read<NotificationDetailCubit>().retryContractLoad();
  }

  @override
  void didPopNext() => _refresh();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && (_route?.isCurrent ?? true)) {
      _refresh();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<NotificationDetailCubit, NotificationDetailState>(
      builder: (context, state) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            context.pop(state.isRead);
          },
          child: Scaffold(
            backgroundColor: colorScheme.surface,
            appBar: AppBar(
              backgroundColor: colorScheme.surface,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
                onPressed: () => context.pop(state.isRead),
              ),
              title: AppText(
                'Chi tiết thông báo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            body: Column(
              children: [
                if (state.isDemo) const NotificationDemoBanner(),
                Expanded(child: _buildBody(context, state)),
                _buildFixedBottomCta(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, NotificationDetailState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 1. Missing data / Error state
    if (state.error != null || state.item == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 56,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              AppText(
                state.error ?? 'Không thể tải chi tiết thông báo',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              AppText(
                'Dữ liệu thông báo này không khả dụng hoặc đã bị thay đổi.',
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 140,
                child: PrimaryButton(
                  text: 'Quay lại',
                  onPressed: () => context.pop(false),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final item = state.item!;
    final contract = state.contract;

    final viewData = NotificationDetailViewData.from(
      context: context,
      item: item,
      contract: contract,
      explicitVariant: state.demoVariant,
      isSigningExpired: state.demoMetadata?['isExpired'] == true,
      isReturnOverdue: state.demoMetadata?['isOverdue'] == true,
    );

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pageMargin,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section B: Notification Summary
          NotificationDetailSummaryCard(viewData: viewData),

          // Section C: NỘI DUNG THÔNG BÁO
          NotificationDetailContentCard(content: item.content),
          const SizedBox(height: 16),

          // Section D Variant D specific: Warning deadline card
          if (item.isExtension && state.contract != null)
            ..._extensionCards(item, state.contract!),
          if (viewData.variant == NotificationDetailVariant.expiringSoon &&
              viewData.warningTime != null &&
              viewData.warningRemaining != null) ...[
            NotificationReturnWarningCard(
              title: viewData.warningTitle ?? 'THỜI HẠN HOÀN TRẢ',
              dueTime: viewData.warningTime!,
              remainingText: viewData.warningRemaining!,
              isOverdue: viewData.isOverdue,
            ),
            const SizedBox(height: 16),
          ],

          // Section D: Related Contract / Device Card
          if (state.contractLoading)
            _buildContractLoadingSkeleton(context)
          else if (state.contractError != null)
            _buildContractErrorCard(context, state.contractError!)
          else if (contract != null)
            NotificationRelatedContractCard(
              contract: contract,
              viewData: viewData,
              metadata: state.demoMetadata,
            )
          else if (item.targetType == NotificationTargetType.contract &&
              item.targetId != null)
            _buildContractUnavailableCard(context, item.targetId!),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _extensionCards(
    NotificationItemModel item,
    ContractModel contract,
  ) {
    final id = item.resolveAppendixId(contract.extensions);
    if (id == null) {
      return [
        const AppText(
          'Thông báo chưa xác định được phụ lục cụ thể. Hãy mở danh sách và chọn đúng yêu cầu gia hạn.',
        ),
      ];
    }
    final row = contract.extensions.singleWhere((r) => r['maPhuLuc'] == id);
    return [
      ContractExtensionCard(
        extension: ExtensionSummary.fromJson(row),
        effectiveReturn: contract.effectiveReturnDate,
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildFixedBottomCta(
    BuildContext context,
    NotificationDetailState state,
  ) {
    if (state.item == null || state.error != null) {
      return const SizedBox.shrink();
    }

    final item = state.item!;
    final contract = state.contract;

    final viewData = NotificationDetailViewData.from(
      context: context,
      item: item,
      contract: contract,
      explicitVariant: state.demoVariant,
      isSigningExpired: state.demoMetadata?['isExpired'] == true,
      isReturnOverdue: state.demoMetadata?['isOverdue'] == true,
    );

    // Check if there is an actionable navigation target.
    // If the notification does not link to a contract, do not show a redundant "Đã xem" button
    // as the AppBar already has a Back button.
    final hasContractTarget =
        item.targetType == NotificationTargetType.contract &&
        item.targetId != null &&
        item.targetId!.isNotEmpty;

    // In demo mode: only show CTA if there is a contract attached
    if (state.isDemo && contract == null) {
      return const SizedBox.shrink();
    }

    // In real mode: only show CTA if there is an actionable contract target
    if (!state.isDemo && !hasContractTarget) {
      return const SizedBox.shrink();
    }

    final isEnabled = !state.contractLoading && viewData.isCtaEnabled;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pageMargin,
          vertical: 12,
        ),
        child: PrimaryButton(
          text: viewData.ctaText,
          suffixIcon:
              viewData.ctaIcon != null
                  ? Icon(viewData.ctaIcon, color: Colors.white, size: 18)
                  : null,
          onPressed:
              isEnabled
                  ? () => _handleCtaAction(context, state, viewData)
                  : null,
        ),
      ),
    );
  }

  void _handleCtaAction(
    BuildContext context,
    NotificationDetailState state,
    NotificationDetailViewData viewData,
  ) {
    // In preview / demo mode: show honest feedback
    if (state.isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bản xem trước — chưa thực hiện thao tác'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final contract = state.contract;
    final targetId = state.item?.targetId;

    if (targetId == null || targetId.isEmpty) {
      context.pop(state.isRead);
      return;
    }

    if (state.item!.isExtension) {
      final appendixId = state.item!.resolveAppendixId(
        contract?.extensions ?? [],
      );
      context.push(
        Uri(
          path: '/contract/$targetId',
          queryParameters: {
            'action': 'renewal',
            if (appendixId != null) 'appendixId': appendixId,
          },
        ).toString(),
      );
      return;
    }

    // Business action based on latest loaded contract status
    if (contract != null) {
      final status = (contract.status ?? '').toUpperCase();
      if (status == 'CHO_KY') {
        context.push('/contract/$targetId', extra: {'action': 'sign'});
      } else if (status == 'DA_KY' || status == 'CHO_BAN_GIAO') {
        context.push('/contract/$targetId');
      } else if (status == 'CHO_HOAN_TRA') {
        context.push('/contract/$targetId/settlement');
      } else if (status == 'DANG_THUE') {
        context.push(
          '/contract/tracking?contractId=$targetId',
          extra: contract,
        );
      } else {
        context.push('/contract/$targetId');
      }
    } else {
      context.push('/contract/$targetId');
    }
  }

  Widget _buildContractLoadingSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final placeholderColor = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.5,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 100,
                height: 14,
                decoration: BoxDecoration(
                  color: placeholderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 60,
                height: 18,
                decoration: BoxDecoration(
                  color: placeholderColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 70,
            decoration: BoxDecoration(
              color: placeholderColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractErrorCard(BuildContext context, String errorMessage) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  'Không thể tải dữ liệu hợp đồng liên kết',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AppText(
            errorMessage,
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed:
                  () =>
                      context
                          .read<NotificationDetailCubit>()
                          .retryContractLoad(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Thử lại'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractUnavailableCard(BuildContext context, String targetId) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              'Thông tin hợp đồng liên quan hiện không khả dụng hoặc bạn không có quyền truy cập.',
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
